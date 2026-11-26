# partnership 网络分析

企业合作关系（partnership）网络分析的代码仓库，其余内容之后陆续加入。

| 文件夹 | 内容 | 数据（Google Drive） |
|---|---|---|
| [replication_jjyj2024/](replication_jjyj2024/) | 复现丁浩员、董文娟、余心玎（2024）《经济研究》：美国加征关税与中国上市公司跨国供应链断裂 | [replication_jjyj2024](https://drive.google.com/drive/folders/1-Y3PqGCeSEIBhMWvMW64X74ipz_6Uw58) |
| [partnership_break/](partnership_break/) | 同样的数据清洗用到合作关系：A 股企业与外国伙伴的合作关系断裂，含知识、资本、市场三大类 | [partnership_break](https://drive.google.com/drive/folders/1ILDiAy1Hn8x2SckaM2snDJqK5aTNf3mq) |
| [full_panel/](full_panel/) | 完整面板：同样的清洗，不截时间、不做样本筛选。A 股企业与境外企业的全部供应链、合作关系，每月一行（2016–2024）；上面两个文件夹的样本都能从中取出 | [full_panel](https://drive.google.com/drive/folders/1cwQiVRA47DKtOOs2zknxc6aH7VuUzqvJ) |

## 供应链的结果是怎么来的：外推

复现文件夹 README 的“外推”一节有完整的表和图，这里只说要点。

- 论文表 2 的回归是 Break = a·Post + Σ b·Post × X + 固定效应，10 个控制变量 X（双方的 Size、Lev、ROA、ATO、Growth）不中心化，所以 a 是 **X 全等于 0 的企业**受的冲击，不是平均企业受的冲击。
- Size = 0 是总资产 1000 万美元。处理组里美国客户的 Size 均值 8.06（约 320 亿美元），供应商 4.52（约 9 亿美元），0 远在样本之外。两个 Size 的 b 都是负的（企业越大，冲击后断得越少），顺着直线外推到 0，a 就被抬高。打个比方：用“身高 0 厘米的人有多重”代表人群的体重。
- 第 (1) 列：在处理组均值处的效应是 −0.008，10 项外推一共加了 0.114，得到 0.107。
- 加固定效应挡不住外推：四列逐列加固定效应，论文写法都显著为正；同样的交互项中心化后，四列都在 −0.006 到 −0.009 之间。
- 事件研究（附图 1）也是外推：论文写法冲击前 p = 0.506，中心化后冲击前 p = 0.085，冲击后显著的是负系数。

合作关系上用同样的思路找外推（partnership_break 的“外推”一节）：伙伴规模 Size_j 外推能得到显著的负效应，但全部合作关系、知识类、资本类的事件研究冲击前就通不过；只有市场类冲击前能过，而市场类只有 19 个处理组关系对。

## 数据

数据不放在仓库里。清洗好的数据、原始数据和本仓库的快照，都在 Google Drive 的总文件夹 `partnership-network-analysis`：

https://drive.google.com/drive/folders/1hjU2et_KQtK56xQwNDDA7rtqlkjIK7-0

| 总文件夹里 | 内容 |
|---|---|
| `README.md` | 总说明：三个分析的主要结果、文件结构、给 AI 的阅读顺序、怎么跑 |
| `code/` | 本仓库的快照（代码、说明、结果表和图），没有 GitHub 权限也能直接用；对应的提交号写在总说明里 |
| `replication_jjyj2024/`、`partnership_break/`、`full_panel/` | 清洗好的数据，与仓库的同名文件夹一一对应（各自的链接见上表） |
| `raw/` | 原始数据：`factset/`（FactSet Revere 关系记录、公司信息）、`other/`（Worldscope、CSMAR、美国加征关税的行业清单），从头重跑清洗时用 |

每个文件夹的 `DATA.md` 写了有哪些数据文件、放进 `data/clean/` 后怎样直接跑回归，以及原始数据放在哪里。
