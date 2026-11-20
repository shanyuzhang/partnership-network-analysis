# partnership 网络分析

企业合作关系（partnership）网络分析的代码仓库，其余内容之后陆续加入。

| 文件夹 | 内容 | 数据（Google Drive） |
|---|---|---|
| [replication_jjyj2024/](replication_jjyj2024/) | 复现丁浩员、董文娟、余心玎（2024）《经济研究》：美国加征关税与中国上市公司跨国供应链断裂 | [replication_jjyj2024](https://drive.google.com/drive/folders/1-Y3PqGCeSEIBhMWvMW64X74ipz_6Uw58) |
| [partnership_break/](partnership_break/) | 同样的数据清洗用到合作关系：A 股企业与外国伙伴的合作关系断裂，含知识、资本、市场三大类 | [partnership_break](https://drive.google.com/drive/folders/1ILDiAy1Hn8x2SckaM2snDJqK5aTNf3mq) |
| [full_panel/](full_panel/) | 完整面板：同样的清洗，不截时间、不做样本筛选。A 股企业与境外企业的全部供应链、合作关系，每月一行（2016–2024）；上面两个文件夹的样本都能从中取出 | [full_panel](https://drive.google.com/drive/folders/1cwQiVRA47DKtOOs2zknxc6aH7VuUzqvJ) |

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
