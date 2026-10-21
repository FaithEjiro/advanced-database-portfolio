"""
CarePoint: Before/after indexing chart (Portfolio 2)
Reads the EXPLAIN ANALYZE evidence files and draws a grouped bar chart.
Run from anywhere: python3 plot_performance.py
"""
import re
import pathlib
import matplotlib
matplotlib.use("Agg")          # no window needed, just save the file
import matplotlib.pyplot as plt
 
base = pathlib.Path(__file__).resolve().parent
ev = base / "evidence"
 
 
def parse(path):
    """Return {query: execution_time_ms} from an EXPLAIN ANALYZE output file."""
    times, current = {}, None
    for line in path.read_text().splitlines():
        m = re.match(r"=== (Q\d+):", line.strip())
        if m:
            current = m.group(1)
        m = re.search(r"Execution Time: ([\d.]+) ms", line)
        if m and current:
            times[current] = float(m.group(1))
    return times
 
 
before = parse(ev / "explain_before.txt")
after = parse(ev / "explain_after.txt")
queries = list(before)
 
names = {
    "Q1": "Q1 Patient\nby phone",
    "Q2": "Q2 Doctor\nschedule",
    "Q7": "Q7 Malaria\nlast 30 days",
    "Q9": "Q9 Recall\nlist",
    "Q10": "Q10 History\nvia view",
}
 
x = range(len(queries))
w = 0.38
fig, ax = plt.subplots(figsize=(10, 5.5))
b1 = ax.bar([i - w / 2 for i in x], [before[q] for q in queries], w,
            label="Before indexes", color="#c0392b")
b2 = ax.bar([i + w / 2 for i in x], [after[q] for q in queries], w,
            label="After indexes", color="#27ae60")
 
ax.set_yscale("log")   # log scale: values range from 0.03 ms to 25 ms
ax.set_ylabel("Execution time (ms, log scale)")
ax.set_title("CarePoint: query execution time before vs after indexing\n"
             "(EXPLAIN ANALYZE, PostgreSQL 17, ~975k rows)")
ax.set_xticks(list(x))
ax.set_xticklabels([names.get(q, q) for q in queries])
ax.bar_label(b1, fmt="%.2f", fontsize=8)
ax.bar_label(b2, fmt="%.2f", fontsize=8)
 
print("| Query | Before (ms) | After (ms) | Result |")
print("|---|---|---|---|")
for i, q in enumerate(queries):
    r = before[q] / after[q]
    if r >= 1.2:
        label = f"{r:.0f}x faster" if r >= 10 else f"{r:.1f}x faster"
    elif r > 0.8:
        label = "no real change"
    else:
        label = "slower*"
    ax.text(i, max(before[q], after[q]) * 2.5, label,
            ha="center", fontsize=9, fontweight="bold")
    print(f"| {q} | {before[q]:.3f} | {after[q]:.3f} | {label} |")
 
ax.set_ylim(top=max(before.values()) * 15)
ax.legend(loc="upper right")
ax.grid(axis="y", alpha=0.3)
fig.tight_layout()
out = ev / "chart_explain_before_after.png"
fig.savefig(out, dpi=150)
print(f"\nChart saved to {out}")
