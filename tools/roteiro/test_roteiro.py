"""Testes do verificador do roteiro de testes manuais (tools/roteiro/roteiro.py).

Rodar: python3 -m unittest discover -s tools/roteiro -v
"""

import copy
import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import roteiro  # noqa: E402


def section(section_id="entrada", covers=None, items=None, **extra):
    return {
        "id": section_id,
        "title": "Entrada",
        "sub": "Teclas e botões",
        "items": items if items is not None else ["Aperte A. Confira se confirma."],
        "covers": covers if covers is not None else ["src/**/*.rs"],
        **extra,
    }


def document(sections=None, watch=None, ignore=None):
    return {
        "versao": 1,
        "watch": watch if watch is not None else ["src/**/*.rs"],
        "ignore": ignore if ignore is not None else [],
        "sections": sections if sections is not None else [section()],
    }


class RepoCase(unittest.TestCase):
    """Cria um repositório de mentira numa pasta temporária."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)
        self.write("src/a.rs", "fn a() {}\n")
        self.write("src/b.rs", "fn b() {}\n")

    def write(self, relative, text):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def remove(self, relative):
        (self.root / relative).unlink()

    def baselined(self, data=None):
        return roteiro.baseline(self.root, data or document())


class StructureTests(unittest.TestCase):
    def errors(self, data):
        return roteiro.validate_structure(data)

    def test_a_minimal_document_is_valid(self):
        self.assertEqual(self.errors(document()), [])

    def test_duplicate_section_ids_are_reported(self):
        data = document([section("x"), section("x")])
        self.assertTrue(any("repetido" in e and "x" in e for e in self.errors(data)))

    def test_ids_must_be_lowercase_words_with_hyphens(self):
        for bad in ["Entrada", "com espaco", "", "a.b"]:
            data = document([section(bad)])
            self.assertTrue(self.errors(data), bad)

    def test_a_section_needs_title_sub_and_items(self):
        for key in ["title", "sub", "items"]:
            s = section()
            del s[key]
            self.assertTrue(self.errors(document([s])), key)

    def test_empty_items_are_reported(self):
        self.assertTrue(self.errors(document([section(items=[])])))

    def test_blank_or_non_text_items_are_reported(self):
        for items in [[""], ["  "], [3]]:
            self.assertTrue(self.errors(document([section(items=items)])), items)

    def test_repeated_items_in_a_section_are_reported(self):
        data = document([section(items=["Igual.", "Igual."])])
        self.assertTrue(any("repetido" in e for e in self.errors(data)))

    def test_covers_must_be_a_list_of_text(self):
        self.assertTrue(self.errors(document([section(covers="src/**")])))
        self.assertTrue(self.errors(document([section(covers=[1])])))

    def test_optional_fields_must_be_text(self):
        self.assertTrue(self.errors(document([section(priority=5)])))
        self.assertTrue(self.errors(document([section(desc=["x"])])))

    def test_watch_and_ignore_must_be_lists(self):
        data = document()
        data["watch"] = "src/**"
        self.assertTrue(self.errors(data))


class CheckTests(RepoCase):
    def test_a_fresh_baseline_passes(self):
        self.assertEqual(roteiro.check(self.root, self.baselined()), [])

    def test_a_changed_covered_file_is_reported_with_its_section(self):
        data = self.baselined()
        self.write("src/a.rs", "fn a() { /* mudou */ }\n")

        errors = roteiro.check(self.root, data)

        joined = "\n".join(errors)
        self.assertIn("entrada", joined)
        self.assertIn("src/a.rs", joined)
        self.assertIn("ack", joined)

    def test_a_new_file_in_a_covered_glob_is_reported(self):
        data = self.baselined()
        self.write("src/c.rs", "fn c() {}\n")

        joined = "\n".join(roteiro.check(self.root, data))

        self.assertIn("src/c.rs", joined)
        self.assertIn("novo", joined)

    def test_a_removed_file_is_reported(self):
        data = self.baselined()
        self.remove("src/b.rs")

        joined = "\n".join(roteiro.check(self.root, data))

        self.assertIn("src/b.rs", joined)
        self.assertIn("removido", joined)

    def test_a_watched_file_without_a_section_must_be_mapped(self):
        data = self.baselined(document([section(covers=["src/a.rs"])]))
        # b.rs está vigiado (src/**/*.rs) mas nenhuma seção o cobre

        joined = "\n".join(roteiro.check(self.root, data))

        self.assertIn("src/b.rs", joined)
        self.assertIn("mapeie", joined)

    def test_ignored_files_need_no_section(self):
        data = self.baselined(
            document([section(covers=["src/a.rs"])], ignore=["src/b.rs"])
        )

        self.assertEqual(roteiro.check(self.root, data), [])

    def test_a_glob_that_matches_nothing_is_reported(self):
        data = self.baselined(document([section(covers=["src/**/*.rs", "nada/**"])]))

        joined = "\n".join(roteiro.check(self.root, data))

        self.assertIn("nada/**", joined)

    def test_manual_only_sections_may_cover_nothing(self):
        data = document(
            [section(), section("longe", covers=[], items=["Sente longe."])]
        )

        self.assertEqual(roteiro.check(self.root, self.baselined(data)), [])

    def test_structure_errors_are_part_of_the_check(self):
        data = self.baselined()
        data["sections"][0]["items"] = []

        self.assertTrue(roteiro.check(self.root, data))

    def test_one_file_may_belong_to_several_sections(self):
        data = document(
            [section("um", covers=["src/**/*.rs"]), section("dois", covers=["src/a.rs"])]
        )
        data = self.baselined(data)
        self.write("src/a.rs", "mudou\n")

        joined = "\n".join(roteiro.check(self.root, data))

        self.assertIn("um", joined)
        self.assertIn("dois", joined)


class AckTests(RepoCase):
    def changed_source(self):
        data = self.baselined()
        self.write("src/a.rs", "fn a() { /* mudou */ }\n")
        return data

    def test_ack_needs_the_items_to_have_changed_or_a_reason(self):
        data = self.changed_source()

        with self.assertRaises(roteiro.AckError):
            roteiro.ack(self.root, data, "entrada")

    def test_ack_is_accepted_when_the_items_changed(self):
        data = self.changed_source()
        data = copy.deepcopy(data)
        data["sections"][0]["items"].append("Aperte B. Confira se volta.")

        new = roteiro.ack(self.root, data, "entrada")

        self.assertEqual(roteiro.check(self.root, new), [])

    def test_ack_is_accepted_with_a_written_reason(self):
        data = self.changed_source()

        new = roteiro.ack(
            self.root, data, "entrada", reason="Só renomeei uma variável.", today="2026-10-20"
        )

        self.assertEqual(roteiro.check(self.root, new), [])
        review = new["sections"][0]["reviews"][-1]
        self.assertEqual(review["reason"], "Só renomeei uma variável.")
        self.assertEqual(review["date"], "2026-10-20")

    def test_a_blank_reason_does_not_count(self):
        data = self.changed_source()

        with self.assertRaises(roteiro.AckError):
            roteiro.ack(self.root, data, "entrada", reason="   ")

    def test_an_unknown_section_is_an_error(self):
        with self.assertRaises(roteiro.AckError):
            roteiro.ack(self.root, self.baselined(), "nao-existe", reason="x")

    def test_ack_does_not_mutate_its_input(self):
        data = self.changed_source()
        before = copy.deepcopy(data)

        roteiro.ack(self.root, data, "entrada", reason="Sem efeito visível.")

        self.assertEqual(data, before)

    def test_ack_only_touches_the_named_section(self):
        data = document(
            [section("um", covers=["src/a.rs"]), section("dois", covers=["src/b.rs"])]
        )
        data = self.baselined(data)
        self.write("src/a.rs", "mudou\n")
        self.write("src/b.rs", "mudou\n")

        new = roteiro.ack(self.root, data, "um", reason="Interno.")

        joined = "\n".join(roteiro.check(self.root, new))
        self.assertIn("dois", joined)
        self.assertNotIn("um:", joined)

    def test_only_the_last_reviews_are_kept(self):
        data = self.baselined()
        for n in range(roteiro.MAX_REVIEWS + 3):
            self.write("src/a.rs", f"versao {n}\n")
            data = roteiro.ack(self.root, data, "entrada", reason=f"motivo {n}")

        reviews = data["sections"][0]["reviews"]

        self.assertEqual(len(reviews), roteiro.MAX_REVIEWS)
        self.assertEqual(reviews[-1]["reason"], f"motivo {roteiro.MAX_REVIEWS + 2}")


class BuildTests(unittest.TestCase):
    TEMPLATE = "<script>var SECTIONS = __ROTEIRO_DATA__;</script>"

    def built(self, data):
        return roteiro.build(data, self.TEMPLATE)

    def test_the_placeholder_is_replaced_by_the_sections(self):
        html = self.built(document())

        self.assertNotIn("__ROTEIRO_DATA__", html)
        self.assertIn("Aperte A. Confira se confirma.", html)

    def test_internal_fields_never_reach_the_page(self):
        data = document([section(reviewed={"src/a.rs": "abc"}, itemsHash="x", reviews=[])])

        html = self.built(data)

        for secret in ["covers", "reviewed", "itemsHash", "reviews", "watch", "ignore"]:
            self.assertNotIn(secret, html)

    def test_public_fields_are_kept(self):
        data = document([section(priority="Precisa de controle", desc="Nota.")])

        html = self.built(data)

        for text in ["Precisa de controle", "Nota.", "Entrada", "Teclas e botões"]:
            self.assertIn(text, html)

    def test_a_closing_script_tag_in_an_item_cannot_break_the_page(self):
        data = document([section(items=["Digite </script><b>oi</b>."])])

        html = self.built(data)

        self.assertEqual(html.count("</script>"), 1)

    def test_a_template_without_the_placeholder_is_rejected(self):
        with self.assertRaises(roteiro.BuildError):
            roteiro.build(document(), "<script></script>")

    def test_the_embedded_data_round_trips_as_json(self):
        data = document([section(items=['Aspas "duplas" e acentuação.'])])

        html = self.built(data)
        start = html.index("SECTIONS = ") + len("SECTIONS = ")
        embedded = json.loads(html[start : html.index(";</script>")].replace("<\\/", "</"))

        self.assertEqual(embedded[0]["items"], ['Aspas "duplas" e acentuação.'])


class CliTests(RepoCase):
    def run_cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = roteiro.main(["--root", str(self.root), *argv])
        return code, out.getvalue(), err.getvalue()

    def save(self, data):
        self.write("docs/roteiro/roteiro.json", json.dumps(data, ensure_ascii=False, indent=2))
        self.write("docs/roteiro/template.html", BuildTests.TEMPLATE)

    def test_check_passes_on_a_clean_baseline(self):
        self.save(self.baselined())

        code, out, _ = self.run_cli("check")

        self.assertEqual(code, 0)
        self.assertIn("em dia", out)

    def test_check_fails_and_explains_when_code_changed(self):
        self.save(self.baselined())
        self.write("src/a.rs", "mudou\n")

        code, _, err = self.run_cli("check")

        self.assertEqual(code, 1)
        self.assertIn("src/a.rs", err)

    def test_ack_refuses_without_changes_or_reason(self):
        self.save(self.baselined())
        self.write("src/a.rs", "mudou\n")

        code, _, err = self.run_cli("ack", "entrada")

        self.assertEqual(code, 1)
        self.assertIn("motivo", err)

    def test_ack_with_a_reason_updates_the_file_and_check_passes(self):
        self.save(self.baselined())
        self.write("src/a.rs", "mudou\n")

        code, _, _ = self.run_cli("ack", "entrada", "--sem-mudanca", "Refatoração interna.")
        check_code, _, _ = self.run_cli("check")

        self.assertEqual(code, 0)
        self.assertEqual(check_code, 0)

    def test_build_writes_the_page(self):
        self.save(self.baselined())
        target = self.root / "dist" / "index.html"

        code, _, _ = self.run_cli("build", "--saida", str(target))

        self.assertEqual(code, 0)
        self.assertIn("Aperte A.", target.read_text(encoding="utf-8"))

    def test_the_saved_file_keeps_accents_and_is_stable(self):
        self.save(self.baselined())
        self.write("src/a.rs", "mudou\n")
        self.run_cli("ack", "entrada", "--sem-mudanca", "Acentuação preservada.")
        first = (self.root / "docs/roteiro/roteiro.json").read_text(encoding="utf-8")

        self.run_cli("ack", "entrada", "--sem-mudanca", "Acentuação preservada.")
        # o segundo ack não tem o que revisar, mas não pode corromper o arquivo
        second = (self.root / "docs/roteiro/roteiro.json").read_text(encoding="utf-8")

        self.assertIn("Acentuação preservada.", first)
        self.assertIn("Acentuação preservada.", second)
        json.loads(second)


if __name__ == "__main__":
    unittest.main()
