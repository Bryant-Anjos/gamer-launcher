#!/usr/bin/env python3
"""Verificador e gerador do roteiro de testes manuais (docs/roteiro).

Regra do projeto: toda alteração de conteúdo (algo que o usuário vê ou faz)
precisa mexer nos testes do roteiro. Cada seção declara quais arquivos de
código cobre (`covers`) e guarda o hash deles na última revisão. Se um
arquivo coberto mudar, ou se aparecer um arquivo vigiado sem seção, `check`
falha. `ack` só libera a seção se os itens mudaram ou se houver um motivo
escrito de por que nenhum teste precisa mudar.

Uso:
    roteiro.py check
    roteiro.py ack SECAO [--sem-mudanca "motivo"]
    roteiro.py baseline
    roteiro.py build [--saida ARQUIVO]
"""

import argparse
import copy
import datetime
import glob
import hashlib
import json
import re
import sys
from pathlib import Path

MAX_REVIEWS = 5
PLACEHOLDER = "__ROTEIRO_DATA__"
HASH_LENGTH = 12
PUBLIC_FIELDS = ("id", "title", "sub", "priority", "desc", "items")
ID_PATTERN = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
DEFAULT_DATA = "docs/roteiro/roteiro.json"
DEFAULT_TEMPLATE = "docs/roteiro/template.html"
DEFAULT_OUTPUT = "dist/roteiro-de-testes.html"
ACK_HINT = 'make roteiro-ack SECAO={id} (ou rode o ack com --sem-mudanca "motivo")'


class AckError(Exception):
    pass


class BuildError(Exception):
    pass


# ---------------------------------------------------------------- estrutura


def _is_text(value):
    return isinstance(value, str) and value.strip() != ""


def _list_of_text(value):
    return isinstance(value, list) and all(isinstance(v, str) for v in value)


def _section_errors(section, index):
    label = section.get("id") if isinstance(section, dict) else None
    label = label if isinstance(label, str) and label else f"#{index + 1}"
    errors = []
    if not isinstance(section, dict):
        return [f"[{label}] a seção deve ser um objeto"]
    if not isinstance(section.get("id"), str) or not ID_PATTERN.match(section["id"]):
        errors.append(f"[{label}] id inválido: use minúsculas, números e hífens")
    for key in ("title", "sub"):
        if not _is_text(section.get(key)):
            errors.append(f"[{label}] falta o campo {key}")
    for key in ("priority", "desc"):
        if key in section and not isinstance(section[key], str):
            errors.append(f"[{label}] {key} deve ser texto")
    items = section.get("items")
    if not isinstance(items, list) or not items:
        errors.append(f"[{label}] a seção precisa de ao menos um item")
    else:
        seen = set()
        for item in items:
            if not _is_text(item):
                errors.append(f"[{label}] item vazio ou que não é texto: {item!r}")
            elif item in seen:
                errors.append(f"[{label}] item repetido: {item[:50]!r}")
            else:
                seen.add(item)
    if not _list_of_text(section.get("covers")):
        errors.append(f"[{label}] covers deve ser uma lista de padrões (use [] só em seção manual)")
    return errors


def validate_structure(data):
    """Erros de forma do documento; lista vazia quando está válido."""
    errors = []
    for key in ("watch", "ignore"):
        if not _list_of_text(data.get(key)):
            errors.append(f"{key} deve ser uma lista de padrões")
    sections = data.get("sections")
    if not isinstance(sections, list) or not sections:
        return errors + ["o documento precisa de seções"]
    seen = set()
    for index, section in enumerate(sections):
        errors.extend(_section_errors(section, index))
        section_id = section.get("id") if isinstance(section, dict) else None
        if section_id in seen:
            errors.append(f"[{section_id}] id repetido")
        seen.add(section_id)
    return errors


# ------------------------------------------------------------------ arquivos


def expand(root, patterns):
    """Arquivos (caminhos relativos, com '/') que casam com os padrões."""
    root = Path(root)
    found = set()
    for pattern in patterns:
        for match in glob.glob(pattern, root_dir=root, recursive=True):
            if (root / match).is_file():
                found.add(Path(match).as_posix())
    return sorted(found)


def _file_hash(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()[:HASH_LENGTH]


def section_files(root, section):
    """{caminho: hash} dos arquivos que a seção cobre."""
    return {path: _file_hash(Path(root) / path) for path in expand(root, section["covers"])}


def items_hash(section):
    payload = json.dumps(section["items"], ensure_ascii=False).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()[:HASH_LENGTH]


def watched_files(root, data):
    ignored = set(expand(root, data["ignore"]))
    return [path for path in expand(root, data["watch"]) if path not in ignored]


# ------------------------------------------------------------------- verificar


def _drift_errors(root, section):
    section_id = section["id"]
    reviewed = section.get("reviewed", {})
    current = section_files(root, section)
    hint = ACK_HINT.format(id=section_id)
    errors = []
    for path in sorted(current.keys() - reviewed.keys()):
        errors.append(f"[{section_id}] arquivo novo coberto: {path}. Revise os itens e rode {hint}")
    for path in sorted(reviewed.keys() - current.keys()):
        errors.append(f"[{section_id}] arquivo removido: {path}. Revise os itens e rode {hint}")
    for path in sorted(current.keys() & reviewed.keys()):
        if current[path] != reviewed[path]:
            errors.append(f"[{section_id}] mudou: {path}. Revise os itens e rode {hint}")
    for pattern in section["covers"]:
        if not expand(root, [pattern]):
            errors.append(f"[{section_id}] o padrão de covers {pattern!r} não casa com nenhum arquivo")
    return errors


def check(root, data):
    """Todos os problemas do roteiro em relação ao código; vazio quando em dia."""
    errors = validate_structure(data)
    if errors:
        return errors
    covered = set()
    for section in data["sections"]:
        covered.update(expand(root, section["covers"]))
        errors.extend(_drift_errors(root, section))
    for path in watched_files(root, data):
        if path not in covered:
            errors.append(
                f"{path}: arquivo vigiado sem seção; mapeie-o em covers de uma seção "
                f"ou acrescente a 'ignore' em {DEFAULT_DATA}"
            )
    return errors


# ------------------------------------------------------------------ revisão


def _replace_section(data, section_id, changes):
    new = copy.deepcopy(data)
    for section in new["sections"]:
        if section["id"] == section_id:
            section.update(changes)
    return new


def baseline(root, data):
    """Marca todas as seções como revisadas agora (uso inicial)."""
    new = copy.deepcopy(data)
    for section in new["sections"]:
        section["reviewed"] = section_files(root, section)
        section["itemsHash"] = items_hash(section)
        section.setdefault("reviews", [])
    return new


def ack(root, data, section_id, reason=None, today=None):
    """Marca uma seção como revisada. Exige itens alterados ou um motivo escrito."""
    section = next((s for s in data["sections"] if s["id"] == section_id), None)
    if section is None:
        raise AckError(f"seção desconhecida: {section_id}")
    reason = (reason or "").strip()
    if items_hash(section) == section.get("itemsHash") and not reason:
        raise AckError(
            f"os itens de {section_id} não mudaram desde a última revisão: "
            "altere os testes ou informe o motivo de nenhum precisar mudar (--sem-mudanca)"
        )
    reviews = list(section.get("reviews", []))
    if reason:
        date = today or datetime.date.today().isoformat()
        reviews.append({"date": date, "reason": reason})
    return _replace_section(
        data,
        section_id,
        {
            "reviewed": section_files(root, section),
            "itemsHash": items_hash(section),
            "reviews": reviews[-MAX_REVIEWS:],
        },
    )


# ------------------------------------------------------------------- gerar


def build(data, template):
    """Página final: o modelo com as seções (só os campos públicos) embutidas."""
    if template.count(PLACEHOLDER) != 1:
        raise BuildError(f"o modelo precisa ter {PLACEHOLDER} exatamente uma vez")
    sections = [
        {key: section[key] for key in PUBLIC_FIELDS if key in section}
        for section in data["sections"]
    ]
    payload = json.dumps(sections, ensure_ascii=False, indent=2)
    # "</" dentro do JSON poderia fechar a tag <script> antes da hora
    return template.replace(PLACEHOLDER, payload.replace("</", "<\\/"))


# -------------------------------------------------------------------- CLI


def _load(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def _save(path, data):
    ordered = copy.deepcopy(data)
    for section in ordered["sections"]:
        if "reviewed" in section:
            section["reviewed"] = dict(sorted(section["reviewed"].items()))
    Path(path).write_text(json.dumps(ordered, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _parser():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("check")
    commands.add_parser("baseline")
    ack_parser = commands.add_parser("ack")
    ack_parser.add_argument("secao")
    ack_parser.add_argument("--sem-mudanca", dest="reason")
    build_parser = commands.add_parser("build")
    build_parser.add_argument("--saida", default=None)
    return parser


def main(argv=None):
    args = _parser().parse_args(argv)
    root = Path(args.root)
    data_path = root / DEFAULT_DATA
    data = _load(data_path)

    if args.command == "check":
        errors = check(root, data)
        if errors:
            print("\n".join(errors), file=sys.stderr)
            print(f"\n{len(errors)} problema(s) no roteiro de testes (docs/roteiro).", file=sys.stderr)
            return 1
        items = sum(len(s["items"]) for s in data["sections"])
        print(f"Roteiro em dia: {len(data['sections'])} seções, {items} itens.")
        return 0

    if args.command == "baseline":
        _save(data_path, baseline(root, data))
        print("Linha de base gravada para todas as seções.")
        return 0

    if args.command == "ack":
        try:
            new = ack(root, data, args.secao, reason=args.reason)
        except AckError as error:
            print(f"erro: {error}", file=sys.stderr)
            return 1
        _save(data_path, new)
        print(f"Seção {args.secao} revisada.")
        return 0

    errors = validate_structure(data)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    try:
        page = build(data, (root / DEFAULT_TEMPLATE).read_text(encoding="utf-8"))
    except BuildError as error:
        print(f"erro: {error}", file=sys.stderr)
        return 1
    target = Path(args.saida) if args.saida else root / DEFAULT_OUTPUT
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(page, encoding="utf-8")
    print(f"Página gerada em {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
