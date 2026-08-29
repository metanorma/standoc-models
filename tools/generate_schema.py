"""Generate a JSON Schema (draft 2020-12) for the StanDoc StandardDocument
from the LML models. Single source: the LML; the schema is derived.

Convention (same as the YAML fixtures): typed nodes carry `class`; keys are
LML attribute names; `text` is a string leaf.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILTINS = {"String": {"type": "string"}, "Integer": {"type": "integer"},
            "Boolean": {"type": "boolean"}, "Float": {"type": "number"},
            "Text": {"type": "string"}, "Date": {"type": "string"},
            "DateTime": {"type": "string"}, "Any": {}}

def model_files():
    # Canonical layers first: flavour views carry drifted inline stubs of
    # shared classes (first definition wins in collect()).
    files = sorted(ROOT.glob("*/models/**/*.lml"))
    files += sorted(ROOT.glob("grammars/basicdoc-models/**/models/**/*.lml"))
    files += sorted(ROOT.glob("grammars/relaton-models/**/models/**/*.lml"))
    # Exclude the basicdoc copy NESTED inside relaton-models (its own
    # submodule): the direct basicdoc-models pin is canonical, and CI does
    # not initialize nested submodules.
    files = [f for f in files if "relaton-models/basicdoc" not in str(f)]
    def order(p):
        top = p.relative_to(ROOT).parts[0]
        return (0 if top == "standoc" else 1 if top == "grammars" else 2, str(p))
    return sorted(files, key=order)

def association_parents():
    # standoc expresses inheritance in view associations (owner/member
    # owner_type inheritance), not only in native `class X < Y` syntax.
    parents = {}
    for v in sorted(ROOT.glob("*/models/*.lml")):
        for m in re.finditer(r"association\s*\{[^}]*?owner\s+(\w+)[^}]*?member\s+(\w+)[^}]*?owner_type\s+inheritance", v.read_text(), re.S):
            parents.setdefault(m.group(2), m.group(1))
    return parents

def collect():
    types = {}
    assoc_parents = association_parents()
    for f in model_files():
        mod = f.relative_to(ROOT).parts[0]
        body = f.read_text()
        for m in re.finditer(r"^\s*(class|enum|data_type|primitive)\s+(\w+)(?:\s*<\s*(\w+))?\s*(?:<<[^>]*>>)?\s*\{", body, re.M):
            kind, name, parent = m.group(1), m.group(2), m.group(3)
            if name in types:
                continue
            attrs, enum_vals = [], []
            for am in re.finditer(r"^\s*[+#-]([a-zA-Z][\w-]*)\s*:\s*([^\[{?\n]+?)(?:\[([^\]]*)\])?\s*\{?\s*$", body, re.M):
                aname, atype, card = am.group(1), am.group(2).strip(), am.group(3)
                atype = re.sub(r"<<[^>]*>>\s*", "", atype).strip()
                attrs.append((aname, atype, card))
            for vm in re.finditer(r"^  ([^\s}]+?)[ ]*(?:\{|$)", body, re.M):
                v = vm.group(1)
                if v != "definition" and re.match(r"^[A-Za-z]", v):
                    enum_vals.append(v)
            types[name] = {"kind": kind, "module": mod, "attrs": attrs,
                           "values": sorted(set(enum_vals)) if kind == "enum" else [],
                           "parent": parent or assoc_parents.get(name)}
    return types

def card_to_schema(card):
    if not card:
        return {"array": False, "min": 1}
    card = card.strip()
    if card in ("*", "0..*"):
        return {"array": True, "min": 0}
    if card == "1..*":
        return {"array": True, "min": 1}
    m = re.match(r"(\d+)\.\.(\d+|\*)$", card)
    if m:
        lo, hi = int(m.group(1)), m.group(2)
        many = hi == "*" or int(hi) > 1
        return {"array": many, "min": lo}
    return {"array": False, "min": 1}

def build(types):
    defs = {}
    for name, info in types.items():
        if info["kind"] == "enum":
            defs[name] = {"enum": info["values"], "title": name}
        elif info["kind"] in ("data_type", "primitive"):
            defs[name] = {"type": "string", "title": name}
        else:
            inherited = []
            seen_parent = info.get("parent")
            while seen_parent and seen_parent in types:
                inherited = types[seen_parent]["attrs"] + inherited
                seen_parent = types[seen_parent].get("parent")
            own_names = {a[0] for a in info["attrs"]}
            all_attrs = info["attrs"] + [a for a in inherited if a[0] not in own_names]
            props, required = {"class": {"type": "string"}}, []
            for aname, atype, card in all_attrs:
                c = card_to_schema(card)
                target = BUILTINS.get(atype)
                if target is None:
                    target = {"$ref": f"#/$defs/{atype}"} if atype in types else {"type": "string"}
                if c["array"]:
                    prop = {"type": "array", "items": target}
                    if c["min"]:
                        prop["minItems"] = c["min"]
                else:
                    prop = dict(target)
                props[aname] = prop
                if not c["array"] and c["min"] >= 1:
                    required.append(aname)
            if not all_attrs:
                defs[name] = {"type": "object", "title": name}
            else:
                node = {"type": "object", "title": name,
                        "properties": props, "additionalProperties": False}
                if required:
                    node["required"] = required
                defs[name] = node
    defs["BasicElement"] = {"oneOf": [{"type": "object", "properties": {"text": {"type": "string"}},
                                      "required": ["text"], "additionalProperties": False},
                                     {"type": "string"}]}
    schema = {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://metanorma.github.io/standoc-models/standoc-2020-12.json",
        "title": "StanDoc StandardDocument (generated from the LML)",
        "$ref": "#/$defs/StandardDocument",
        "$defs": defs,
    }
    return schema

def main(out=None):
    types = collect()
    schema = build(types)
    out = Path(out) if out else ROOT / "schema" / "standoc-2020-12.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(schema, indent=2, ensure_ascii=False) + "\n")
    print(f"schema: {len(schema['$defs'])} definitions -> {out}")

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else None)
