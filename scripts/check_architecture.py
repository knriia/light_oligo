#!/usr/bin/env python3
"""Проверка границ целевых модулей Lazarus/Free Pascal."""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from dataclasses import dataclass
from fnmatch import fnmatchcase
from pathlib import Path
from typing import Iterable


IDENTIFIER_START = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"
IDENTIFIER_CHARS = IDENTIFIER_START + "0123456789"


@dataclass(frozen=True)
class Token:
    value: str
    line: int


@dataclass(frozen=True)
class UseReference:
    name: str
    line: int
    section: str


@dataclass
class ParsedSource:
    path: Path
    declared_name: str | None
    kind: str | None
    uses: list[UseReference]
    parse_error: str | None = None


@dataclass(frozen=True)
class Violation:
    rule: str
    unit: str
    path: Path
    line: int
    message: str


def load_text(path: Path) -> str:
    """Файлы проекта обычно UTF-8; запасной вариант нужен для старых cp1251-файлов."""
    raw = path.read_bytes()
    for encoding in ("utf-8-sig", "cp1251", "latin-1"):
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            continue
    raise UnicodeDecodeError("unknown", raw, 0, len(raw), "не удалось декодировать файл")


def tokenize_pascal(text: str) -> list[Token]:
    """Лексически убирает комментарии и строки, сохраняя номера строк.

    Директивы {$...} намеренно считаются комментариями: код uses после {$IFDEF}
    всё равно остаётся в потоке и проверяется независимо от активного define.
    """
    tokens: list[Token] = []
    index = 0
    line = 1
    length = len(text)

    while index < length:
        char = text[index]

        if char in " \t\r\n":
            if char == "\n":
                line += 1
            index += 1
            continue

        if text.startswith("//", index):
            index += 2
            while index < length and text[index] != "\n":
                index += 1
            continue

        if char == "{" or text.startswith("(*", index):
            opener = "{" if char == "{" else "(*"
            closer = "}" if opener == "{" else "*)"
            depth = 1
            index += len(opener)
            while index < length and depth:
                if text.startswith(opener, index):
                    depth += 1
                    index += len(opener)
                elif text.startswith(closer, index):
                    depth -= 1
                    index += len(closer)
                else:
                    if text[index] == "\n":
                        line += 1
                    index += 1
            continue

        if char == "'":
            # Строки не должны превращать текст вроде 'uses X' в секцию uses.
            index += 1
            while index < length:
                if text[index] == "\n":
                    line += 1
                if text[index] == "'":
                    if index + 1 < length and text[index + 1] == "'":
                        index += 2
                        continue
                    index += 1
                    break
                index += 1
            continue

        if char in IDENTIFIER_START:
            start_line = line
            start = index
            index += 1
            while index < length and text[index] in IDENTIFIER_CHARS:
                index += 1
            tokens.append(Token(text[start:index], start_line))
            continue

        tokens.append(Token(char, line))
        index += 1

    return tokens


def parse_source(path: Path) -> ParsedSource:
    try:
        tokens = tokenize_pascal(load_text(path))
    except (OSError, UnicodeDecodeError) as error:
        return ParsedSource(path, None, None, [], f"ошибка чтения: {error}")

    declared_name: str | None = None
    kind: str | None = None
    for index, token in enumerate(tokens[:-1]):
        keyword = token.value.lower()
        if keyword in {"unit", "program", "library", "package"}:
            if tokens[index + 1].value not in {";", "."}:
                declared_name = tokens[index + 1].value
                kind = keyword
                break

    if declared_name is None:
        return ParsedSource(path, None, None, [], "не найдено объявление unit/program")

    uses: list[UseReference] = []
    section = "program" if kind != "unit" else "before-interface"
    index = 0
    while index < len(tokens):
        token = tokens[index]
        keyword = token.value.lower()
        if kind == "unit" and keyword in {"interface", "implementation"}:
            section = keyword
            index += 1
            continue
        if keyword != "uses" or (kind == "unit" and section not in {"interface", "implementation"}):
            index += 1
            continue

        index += 1
        while index < len(tokens) and tokens[index].value != ";":
            current = tokens[index]
            current_lower = current.value.lower()
            if current_lower == "in":
                # Редкая форма uses UnitName in 'filename'; — строка уже пропущена.
                index += 1
                while index < len(tokens) and tokens[index].value not in {",", ";"}:
                    index += 1
                continue
            if current.value == ",":
                index += 1
                continue
            if current.value == ".":
                index += 1
                continue
            if current.value in {";", "="}:
                index += 1
                continue
            if current.value[0] in IDENTIFIER_START:
                name_parts = [current.value]
                name_line = current.line
                index += 1
                while (
                    index + 1 < len(tokens)
                    and tokens[index].value == "."
                    and tokens[index + 1].value[0] in IDENTIFIER_START
                ):
                    name_parts.extend((tokens[index].value, tokens[index + 1].value))
                    index += 2
                uses.append(UseReference("".join(name_parts), name_line, section))
                continue
            index += 1
        if index < len(tokens) and tokens[index].value == ";":
            index += 1

    return ParsedSource(path, declared_name, kind, uses)


def relative_path(root: Path, path: Path) -> str:
    return path.relative_to(root).as_posix()


def is_excluded(root: Path, path: Path, patterns: Iterable[str]) -> bool:
    relative = relative_path(root, path).lower()
    return any(fnmatchcase(relative, pattern.lower()) for pattern in patterns)


def discover_sources(
    root: Path,
    patterns: Iterable[str],
    exclude_patterns: Iterable[str],
) -> list[Path]:
    paths: set[Path] = set()
    for pattern in patterns:
        paths.update(
            path
            for path in root.glob(pattern)
            if path.is_file() and not is_excluded(root, path, exclude_patterns)
        )
    return sorted(paths, key=lambda path: path.as_posix().lower())


def normalize_mapping(raw_mapping: dict[str, str]) -> dict[str, str]:
    return {name.lower(): module for name, module in raw_mapping.items()}


def find_cycles(graph: dict[str, set[str]]) -> list[list[str]]:
    """Возвращает циклические компоненты графа, без повторов из-за точки старта."""
    index = 0
    stack: list[str] = []
    on_stack: set[str] = set()
    indices: dict[str, int] = {}
    low_links: dict[str, int] = {}
    components: list[list[str]] = []

    def visit(node: str) -> None:
        nonlocal index
        indices[node] = index
        low_links[node] = index
        index += 1
        stack.append(node)
        on_stack.add(node)

        for target in sorted(graph.get(node, set())):
            if target not in indices:
                visit(target)
                low_links[node] = min(low_links[node], low_links[target])
            elif target in on_stack:
                low_links[node] = min(low_links[node], indices[target])

        if low_links[node] != indices[node]:
            return
        component: list[str] = []
        while True:
            current = stack.pop()
            on_stack.remove(current)
            component.append(current)
            if current == node:
                break
        if len(component) > 1 or node in graph.get(node, set()):
            components.append(sorted(component))

    for node in sorted(graph):
        if node not in indices:
            visit(node)
    return sorted(components)


def validate_config(config: dict, modules: set[str]) -> list[str]:
    errors: list[str] = []
    allowed_edges = config.get("allowed_edges", {})
    if set(allowed_edges) != modules:
        errors.append(
            "allowed_edges должен содержать ровно объявленные модули: "
            f"{sorted(modules ^ set(allowed_edges))}"
        )
    for source, targets in allowed_edges.items():
        unknown_targets = set(targets) - modules
        if unknown_targets:
            errors.append(f"{source}: неизвестные целевые модули {sorted(unknown_targets)}")
    mapping = config.get("unit_modules", {})
    mapping_modules = set(mapping.values())
    if modules - mapping_modules:
        errors.append(f"в unit_modules не используются модули: {sorted(modules - mapping_modules)}")
    for unit, module in mapping.items():
        if module not in modules:
            errors.append(f"{unit}: неизвестный модуль {module}")
    return errors


def format_violation(root: Path, violation: Violation) -> str:
    return (
        f"- {violation.unit} — {relative_path(root, violation.path)}:{violation.line} — "
        f"{violation.message}"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Проверка архитектурных границ Pascal-проекта")
    parser.add_argument("--strict", action="store_true", help="завершиться с кодом 1 при любом нарушении")
    parser.add_argument(
        "--config",
        type=Path,
        default=Path("scripts/architecture/modules.json"),
        help="путь к конфигурации относительно корня проекта",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent
    config_path = args.config if args.config.is_absolute() else root / args.config
    try:
        config = json.loads(config_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"Ошибка конфигурации {config_path}: {error}", file=sys.stderr)
        return 2

    unit_modules = normalize_mapping(config.get("unit_modules", {}))
    modules = set(config.get("modules", []))
    config_errors = validate_config(config, modules)
    sources = discover_sources(
        root,
        config.get("source_globs", []),
        config.get("exclude", []),
    )
    parsed_sources = [parse_source(path) for path in sources]

    by_unit: dict[str, ParsedSource] = {}
    for source in parsed_sources:
        if source.declared_name is None:
            config_errors.append(f"{relative_path(root, source.path)}: {source.parse_error}")
            continue
        key = source.declared_name.lower()
        if key in by_unit:
            config_errors.append(
                f"дублируется имя юнита {source.declared_name}: "
                f"{relative_path(root, by_unit[key].path)} и {relative_path(root, source.path)}"
            )
        else:
            by_unit[key] = source

    unmapped: list[ParsedSource] = []
    for source in parsed_sources:
        if source.declared_name and source.declared_name.lower() not in unit_modules:
            unmapped.append(source)

    for mapped_name in sorted(set(unit_modules) - set(by_unit)):
        config_errors.append(f"юнит {mapped_name} есть в карте, но не найден среди исходников")

    visual_units = {name.lower() for name in config.get("visual_units", [])}
    exceptions = {name.lower() for name in config.get("rule2_exceptions", [])}
    allowed_edges = {
        source: set(targets) for source, targets in config.get("allowed_edges", {}).items()
    }

    edge_violations: list[Violation] = []
    visual_violations: list[Violation] = []
    module_graph = {module: set() for module in modules}

    for source in parsed_sources:
        if not source.declared_name or source.declared_name.lower() not in unit_modules:
            continue
        owner_module = unit_modules[source.declared_name.lower()]
        for reference in source.uses:
            dependency = by_unit.get(reference.name.lower())
            if dependency and dependency.declared_name:
                dependency_module = unit_modules.get(dependency.declared_name.lower())
                if dependency_module and dependency_module != owner_module:
                    module_graph.setdefault(owner_module, set()).add(dependency_module)
                    if dependency_module not in allowed_edges.get(owner_module, set()):
                        edge_violations.append(
                            Violation(
                                "правило 1",
                                source.declared_name,
                                source.path,
                                reference.line,
                                f"запрещено ребро {owner_module} -> {dependency_module} "
                                f"через uses {reference.name} ({reference.section})",
                            )
                        )

            if (
                source.kind == "unit"
                and not source.declared_name.lower().startswith("u")
                and source.declared_name.lower() not in exceptions
                and reference.name.lower() in visual_units
            ):
                visual_violations.append(
                    Violation(
                        "правило 2",
                        source.declared_name,
                        source.path,
                        reference.line,
                        f"логический unit без префикса U подключает визуальный unit {reference.name} "
                        f"({reference.section})",
                    )
                )

    cycles = find_cycles(module_graph)
    edge_groups: dict[str, list[Violation]] = defaultdict(list)
    for violation in edge_violations:
        edge = violation.message.split(" через", 1)[0].removeprefix("запрещено ребро ")
        edge_groups[edge].append(violation)

    print(f"Конфигурация: {relative_path(root, config_path)}")
    print(f"Исходных файлов: {len(sources)}")
    unit_count = sum(source.kind == "unit" for source in parsed_sources)
    program_count = sum(source.kind == "program" for source in parsed_sources)
    print(f"Юнитов: {unit_count}")
    print(f"Program: {program_count}")
    print()

    print("Сводка")
    print(f"- юнитов без модуля: {len(unmapped)}")
    print(f"- нарушений правила 1 (запрещённые рёбра): {len(edge_violations)}")
    print(f"- нарушений правила 2 (LCL в логике): {len(visual_violations)}")
    print(f"- циклов модулей: {len(cycles)}")
    print(f"- ошибок конфигурации: {len(config_errors)}")

    print("\nПравило 1 — запрещённые рёбра")
    if not edge_groups:
        print("- нет")
    else:
        for edge in sorted(edge_groups):
            violations = edge_groups[edge]
            print(f"\n{edge} — {len(violations)}")
            for violation in violations:
                print(format_violation(root, violation))

    print("\nПравило 2 — визуальные LCL-зависимости")
    if not visual_violations:
        print("- нет")
    else:
        for violation in visual_violations:
            print(format_violation(root, violation))

    print("\nЦиклы")
    if not cycles:
        print("- нет")
    else:
        for cycle in cycles:
            internal_edges = []
            for source in cycle:
                for target in sorted(module_graph[source] & set(cycle)):
                    internal_edges.append(f"{source} -> {target}")
            print(f"- циклическая компонента: {', '.join(cycle)}; рёбра: {', '.join(internal_edges)}")

    print("\nЮниты без модуля")
    if not unmapped:
        print("- нет")
    else:
        for source in unmapped:
            print(f"- {source.declared_name} — {relative_path(root, source.path)}:1")

    print("\nОшибки конфигурации")
    if not config_errors:
        print("- нет")
    else:
        for error in config_errors:
            print(f"- {error}")

    print("\nСпорные места карты и допущения")
    for note in config.get("mapping_notes", []):
        print(f"- {note}")

    has_violations = bool(unmapped or edge_violations or visual_violations or cycles or config_errors)
    if args.strict and has_violations:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
