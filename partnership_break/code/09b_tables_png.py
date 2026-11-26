"""09b_tables_png.py —— 把 09 的外推结果做成三张表格图（PNG）

输入：output/tables/extrap_sizej_fe.csv、extrap_es.csv、extrap_grid.csv（09 生成）
      ../replication_jjyj2024/output/tables/extrapolation.csv、extrapolation_es.csv（复现文件夹的 07 生成）
输出：output/figures/extrap_table1_all.png      全部合作关系：Size_j 外推，只列 Post x Impact 显著的列
      output/figures/extrap_table2_types.png    三大类：同上
      output/figures/extrap_table3_fe_es.png    供应链与合作关系：外推 / 中心化 / 不加交互项，四列固定效应与事件研究

做法：先写 HTML，再用 Chrome 的无界面模式截图。只用 Python 标准库；需要 Google Chrome
（默认 macOS 的安装位置，别处时设环境变量 CHROME）。在 partnership_break 文件夹里运行：
    python3 code/09b_tables_png.py
"""
import csv
import os
import re
import subprocess
import tempfile

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TAB = os.path.join(HERE, "output", "tables")
FIG = os.path.join(HERE, "output", "figures")
REP = os.path.join(HERE, "..", "replication_jjyj2024", "output", "tables")
CHROME = os.environ.get("CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")


def rd(path):
    with open(path, encoding="utf-8") as f:
        return list(csv.DictReader(f))


fe = {(r["grp"], r["spec"], int(r["s"])): r for r in rd(os.path.join(TAB, "extrap_sizej_fe.csv"))}
es_p = {}
es_b = {}
for r in rd(os.path.join(TAB, "extrap_es.csv")):
    es_p[("partner", r["grp"], r["spec"])] = (float(r["pre_p"]), float(r["post_p"]))
    es_b[(r["grp"], r["spec"], int(r["k"]))] = float(r["b"]) if r["b"] not in ("", ".") else None
grid = {(r["grp"], r["x"], int(r["col"])): r for r in rd(os.path.join(TAB, "extrap_grid.csv"))}
sup = {(r["spec"], int(r["col"])): r for r in rd(os.path.join(REP, "extrapolation.csv"))}
sup_es_b = {}
for r in rd(os.path.join(REP, "extrapolation_es.csv")):
    es_p[("supply", "ALL", r["spec"])] = (float(r["pre_p"]), float(r["post_p"]))
    sup_es_b[(r["spec"], int(r["k"]))] = (float(r["b"]), float(r["se"]))


def star(p):
    p = float(p)
    return "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.1 else ""


def num(x):
    return f"{float(x):.4f}".replace("-", "−")


def cell(b, se, p):
    return f'{num(b)}{star(p)}<br><span class="se">({float(se):.4f})</span>'


def pf(x):
    return "&lt; 0.001" if x < 0.001 else f"= {x:.3f}"


CSS = """<style>
body{font-family:"PingFang SC","Hiragino Sans GB","Microsoft YaHei",sans-serif;background:#fff;color:#111;margin:0;padding:28px 34px;}
#w{display:inline-block}
h1{font-size:21px;margin:0 0 6px 0;font-weight:600} .sub{font-size:13.5px;color:#444;margin-bottom:14px;line-height:1.5;max-width:1000px}
table{border-collapse:collapse;font-size:14.5px} th,td{padding:6px 14px;text-align:center;white-space:nowrap}
td:first-child,th:first-child{text-align:left}
thead tr:first-child th{border-top:2px solid #111} thead tr:last-child th{border-bottom:1px solid #111}
tbody tr.last td{border-bottom:2px solid #111} tr.mid td{border-top:1px solid #999}
.se{color:#555;font-size:12.5px} .grp{font-weight:600} .note{font-size:12.5px;color:#444;margin-top:10px;line-height:1.6;max-width:1000px}
.panel td{font-weight:600;text-align:left;background:#f3f3f3}
</style>"""


def page(title, sub, table, note):
    return (f'<!doctype html><html><head><meta charset="utf-8">{CSS}</head><body><div id="w"><h1>{title}</h1>'
            f'<div class="sub">{sub}</div>{table}<div class="note">{note}</div></div></body></html>')


FEROW = {0: ("否", "否", "否", "否", "A 股企业"), 1: ("是", "否", "否", "否", "关系对"), 2: ("是", "是", "否", "否", "关系对"),
         3: ("是", "是", "是", "否", "关系对"), 4: ("是", "是", "是", "是", "关系对")}
COLN = {0: "无 FE", 1: "(1)", 2: "(2)", 3: "(3)", 4: "(4)"}


def reg_table(cols):
    h1 = "<tr><th></th>" + "".join(f'<th class="grp">{g}</th>' for g, _, _, _ in cols) + "</tr>"
    h2 = "<tr><th></th>" + "".join(f"<th>{l}</th>" for _, l, _, _ in cols) + "</tr>"
    rows = []

    def row(lab, f, cls=""):
        rows.append(f'<tr class="{cls}"><td>{lab}</td>'
                    + "".join(f"<td>{f(fe[(g, 'paper', s)], s)}</td>" for _, _, g, s in cols) + "</tr>")

    row("Post × Impact（Size_j = 0）", lambda r, s: cell(r["b"], r["se"], r["p"]))
    row("Post × Impact × Size_j", lambda r, s: cell(r["g"], r["gse"], r["gp"]))
    row("Size_j 取处理组冲击后均值时的效应", lambda r, s: cell(r["b_mean"], r["se_mean"], r["p_mean"]), "mid")
    row("处理组冲击后 Size_j 均值", lambda r, s: f"{float(r['mean_x']):.2f}")
    labs = ["关系对 FE + 月份 FE", "+ A 股企业行业 × 年 FE", "+ A 股企业 × 年 FE", "+ 伙伴 × 年 FE", "聚类"]
    for i, lab in enumerate(labs):
        row(lab, lambda r, s, i=i: FEROW[s][i], "mid" if i == 0 else "")
    row("观测值", lambda r, s: f"{int(r['N']):,}", "mid")
    row("处理组关系对", lambda r, s: r["ntr"], "last")
    return f'<table><thead>{h1}{h2}</thead><tbody>{"".join(rows)}</tbody></table>'


def sig(g, s):
    return float(fe[(g, "paper", s)]["p"]) < 0.10


def nonsig_text(g):
    return "、".join(f"{COLN[s]} {num(fe[(g, 'paper', s)]['b'])}（p = {float(fe[(g, 'paper', s)]['p']):.3f}）"
                    for s in range(5) if not sig(g, s))


# ---- 表 1 ----
cols = [("全部合作关系", COLN[s], "ALL", s) for s in range(5) if sig("ALL", s)]
pre, post = es_p[("partner", "ALL", "paper")]
fm = grid[("ALL", "size_j", 3)]
t1 = page(
    "表 1　全部合作关系：伙伴规模 Size_j 外推，显著的 Post × Impact（p &lt; 0.10）",
    "被解释变量：Break。Post × Impact × Size_j 不中心化，Post × Impact 是 Size_j = 0（伙伴总资产 1000 万美元）时的效应。"
    "(1)–(4) 为论文表 2 的固定效应写法；只列出 Post × Impact 显著的列。",
    reg_table(cols),
    "括号内为聚类标准误；* p&lt;0.10，** p&lt;0.05，*** p&lt;0.01。Size_j = ln(伙伴 2017 年总资产美元 / 1000 万)，在样本上按 1%/99% 缩尾；"
    f"只用伙伴有 Size_j 的观测。不显著的列：{nonsig_text('ALL')}；加 A 股企业 × 月 FE 也不显著"
    f"（{num(fm['b'])}，p = {float(fm['p']):.3f}）。"
    f"<br>事件研究（论文式 (2)，相对月份 × 处理组 × Size_j 不中心化，关系对 + 月份 FE）：冲击前 5 个系数联合为 0 的 p {pf(pre)}，"
    f"冲击后 p {pf(post)}，<b>不能通过平行趋势检验</b>：冲击前的系数为正（−6 月 {num(es_b[('ALL', 'paper', -6)])}、"
    f"−5 月 {num(es_b[('ALL', 'paper', -5)])}），冲击后回到 0 附近，负的 Post × Impact 来自冲击前偏高。")

# ---- 表 2 ----
cols = []
for g, nm in [("K", "K 知识类"), ("C", "C 资本类"), ("M", "M 市场类")]:
    cols += [(nm, COLN[s], g, s) for s in range(5) if sig(g, s)]
esn = "；".join(f"{g} 冲击前 p {pf(es_p[('partner', g, 'paper')][0])}、冲击后 p {pf(es_p[('partner', g, 'paper')][1])}"
               for g in "KCM")
t2 = page(
    "表 2　三大类：伙伴规模 Size_j 外推，显著的 Post × Impact（p &lt; 0.10）",
    "写法同表 1，每一类在自己的样本上缩尾、估计；只列出 Post × Impact 显著的列。",
    reg_table(cols),
    f"括号内为聚类标准误；* p&lt;0.10，** p&lt;0.05，*** p&lt;0.01。不显著的列：C {nonsig_text('C')}；"
    f"M {nonsig_text('M')}。M 只有 {fe[('M', 'paper', 0)]['ntr']} 个处理组关系对。"
    f"<br>事件研究（同表 1）：{esn}。")


# ---- 表 3 ----
def srow(spec, lab):
    return f"<tr><td>{lab}</td>" + "".join(
        f"<td>{cell(sup[(spec, k)]['b'], sup[(spec, k)]['se'], sup[(spec, k)]['p'])}</td>" for k in range(1, 5)) + "</tr>"


def prow(spec, lab):
    return f"<tr><td>{lab}</td>" + "".join(
        f"<td>{cell(fe[('ALL', spec, k)]['b'], fe[('ALL', spec, k)]['se'], fe[('ALL', spec, k)]['p'])}</td>" for k in range(1, 5)) + "</tr>"


def erow(study, spec, lab, cls=""):
    a, b = es_p[(study, "ALL", spec)]
    return f'<tr class="{cls}"><td>{lab}</td><td colspan="4" style="text-align:left">冲击前 p {pf(a)}　　冲击后 p {pf(b)}</td></tr>'


body = ('<tr class="panel"><td colspan="5">A. 供应链（replication_jjyj2024，论文表 2：i、j 各 5 个财务交互项）</td></tr>'
        + srow("paper", "论文写法：交互项不中心化（外推到 0）") + srow("cen", "同样的交互项，在处理组均值处中心化")
        + srow("none", "不加交互项") + erow("supply", "paper", "事件研究，论文写法（不中心化）")
        + erow("supply", "cen", "事件研究，中心化")
        + '<tr class="panel"><td colspan="5">B. 合作关系（交互项只用伙伴规模 Size_j）</td></tr>'
        + prow("paper", "不中心化（外推到 Size_j = 0）") + prow("cen", "在处理组均值处中心化") + prow("none", "不加交互项")
        + erow("partner", "paper", "事件研究，不中心化") + erow("partner", "cen", "事件研究，中心化")
        + erow("partner", "paperi5", "事件研究，不中心化，再加 A 股企业 5 项", "last"))
head = ("<tr><th></th><th>(1)</th><th>(2)</th><th>(3)</th><th>(4)</th></tr>"
        "<tr><th></th><th>关系对 + 月份 FE</th><th>+ 行业 × 年</th><th>+ A 股企业 × 年</th><th>+ 伙伴 × 年</th></tr>")
cen = [float(sup[("cen", k)]["b"]) for k in range(1, 5)]
neg = min(((k, sup_es_b[("cen", k)]) for k in range(0, 7)), key=lambda z: z[1][0] / z[1][1])
t3 = page(
    "表 3　外推的作用：加固定效应、事件研究",
    "被解释变量：Break；表中为 Post × Impact 的系数，按关系对聚类（论文的写法）。事件研究为论文式 (2)：相对月份 −6 到 +6，"
    "以 −1 为基期，关系对 + 月份 FE；p 为冲击前 5 个、冲击后 7 个系数分别联合为 0 的检验。",
    f"<table><thead>{head}</thead><tbody>{body}</tbody></table>",
    "* p&lt;0.10，** p&lt;0.05，*** p&lt;0.01。中心化只改变交互项的取值原点，不改变模型的拟合：Post × Impact 从“X = 0 时的效应”"
    "变成“X 取处理组均值时的效应”，与不加交互项几乎一样。"
    f"<br>A：四列逐列加固定效应，外推出的正效应都还在；中心化后在 {num(min(cen))} 到 {num(max(cen))} 之间。"
    f"事件研究：不中心化时冲击前 p {pf(es_p[('supply', 'ALL', 'paper')][0])}；中心化后冲击前 p {pf(es_p[('supply', 'ALL', 'cen')][0])}，"
    f"冲击后最显著的是负系数（+{neg[0]} 月 {num(neg[1][0])}）。"
    "<br>B：Size_j 的外推加固定效应后只有部分列显著；事件研究不中心化时冲击前就不能通过。")

os.makedirs(FIG, exist_ok=True)
tmp = tempfile.mkdtemp()
for name, html in [("extrap_table1_all", t1), ("extrap_table2_types", t2), ("extrap_table3_fe_es", t3)]:
    hp = os.path.join(tmp, name + ".html")
    with open(hp, "w", encoding="utf-8") as f:
        f.write(html)
    # 先量出内容的宽高，再按这个大小截图
    mp = os.path.join(tmp, name + "_m.html")
    with open(mp, "w", encoding="utf-8") as f:
        f.write(html.replace("</body>", '<script>var w=document.getElementById("w");'
                             'document.body.setAttribute("data-w",w.offsetWidth+70);'
                             'document.body.setAttribute("data-h",w.offsetHeight+58);</script></body>'))
    common = [CHROME, "--headless=new", "--disable-gpu", "--no-first-run", "--hide-scrollbars"]
    dom = subprocess.run(common + ["--window-size=2400,3000", "--dump-dom", "file://" + mp],
                         capture_output=True, text=True).stdout
    w, h = re.search(r'data-w="(\d+)" data-h="(\d+)"', dom).groups()
    out = os.path.join(FIG, name + ".png")
    subprocess.run(common + ["--force-device-scale-factor=2", f"--window-size={w},{h}", f"--screenshot={out}", "file://" + hp],
                   capture_output=True)
    print(out, w, h)
