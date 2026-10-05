"""Collect a hearing's results from the workflow journal.

Usage:
    python collect_results.py <workflow transcript dir> <out dir> [name ...]

Writes one file per case into <out dir>/hearings/ (both briefs and the judge's decision), a
`results.tsv` with verdict, confidence, case type and the advocates' own strength, and prints the
judge's reading for the named cases (all of them when no name is given). The transcript dir is the
one the Workflow tool reports; its `journal.jsonl` holds one result line per agent, labelled
"P <name>", "D <name>", "J <name>".
"""
import json
import os
import sys


def facts(xs):
    return "\n".join("- " + x for x in xs)


def main():
    run, out = sys.argv[1], sys.argv[2]
    show = sys.argv[3:]
    rows = [json.loads(l) for l in open(os.path.join(run, "journal.jsonl"), encoding="utf-8")]
    label = {r["agentId"]: r["label"] for r in rows if r.get("type") == "started"}
    res = {label[r["agentId"]]: r["result"] for r in rows if r.get("type") == "result"}
    names = [l[2:] for l in res if l.startswith("J ")]
    os.makedirs(os.path.join(out, "hearings"), exist_ok=True)

    table = ["Player\tHearing\tConfidence\tCaseType\tProsecutionStrength\tDefenceStrength"]
    for name in names:
        p, d, j = res.get("P " + name), res.get("D " + name), res["J " + name]
        text = ["# Hearing: %s" % name, "",
                "Verdict of the judge: **%s**, confidence %d of 10, %s case." % (j["verdict"], j["confidence"], j["case_type"]), ""]
        for title, b in (("Prosecution", p), ("Defence", d)):
            if b:
                text += ["## %s (own strength %d of 10)" % (title, b["strength"]), "", b["brief"], "",
                         "Strongest facts:", "", facts(b["strongest_facts"]), "", "Own weakest point: " + b["weakest_point"], ""]
        text += ["## Judge", "", j["what_happened"], "", "Decisive facts:", "", facts(j["decisive_facts"]), "",
                 "Prosecution claims that did not hold: " + j["prosecution_check"], "",
                 "Defence claims that did not hold: " + j["defence_check"], "",
                 "What would change the verdict: " + j["would_change"], ""]
        slug = name.lower().replace(".", "-").replace("_", "-").replace(" ", "-")
        with open(os.path.join(out, "hearings", slug + ".md"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\n".join(text))
        table.append("\t".join(str(x) for x in (name, j["verdict"], j["confidence"], j["case_type"],
                                                 p["strength"] if p else "", d["strength"] if d else "")))
    with open(os.path.join(out, "results.tsv"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(table) + "\n")

    for name in (show or names):
        j = res["J " + name]
        print("\n=====", name, "|", j["verdict"], j["confidence"], j["case_type"])
        print("WHAT:", j["what_happened"])
        print("FACTS:", " || ".join(j["decisive_facts"]))
        print("CHANGE:", j["would_change"])
    print("\n" + "\n".join(table))


if __name__ == "__main__":
    main()
