# 数据说明

数据不放在 GitHub 上，清洗好的数据和原始数据都在 Google Drive。原始数据下载后按下面的路径放好即可。

## 清洗好的数据（Google Drive）

**链接：** https://drive.google.com/drive/folders/1ILDiAy1Hn8x2SckaM2snDJqK5aTNf3mq

（它在 Drive 文件夹 `partnership-network-analysis` 下，与本仓库的文件夹一一对应：<https://drive.google.com/drive/folders/1hjU2et_KQtK56xQwNDDA7rtqlkjIK7-0>）

把下载的文件放进本文件夹的 `data/clean/`，再把 `code/run_all.do` 里的 `local clean 1` 改成 `local clean 0`，运行 `do code/run_all.do`，就只跑 04–09。

| 文件 | 内容 | 观测值 × 变量 | 用在 |
|---|---|---:|---|
| `analysis_sample.dta` | 全部合作关系的回归样本：2017m1–2019m12，每对只看 2017 年起的第一段，回归用的变量都已生成 | 42,332 × 39 | 04、06、07、08、09 |
| `analysis_K.dta` | 知识类的回归样本 | 18,896 × 39 | 06、07、08、09 |
| `analysis_C.dta` | 资本类的回归样本 | 22,860 × 39 | 06、07、08、09 |
| `analysis_M.dta` | 市场类的回归样本 | 1,937 × 39 | 06、07、08、09 |
| `panel_monthly.dta` | 全部合作关系，2017m1–2020m6 的关系对 × 月面板，已做全部样本筛选，不限第一段 | 50,852 × 28 | 05 |

08 的存续率、数量和整批结束还要用 full_panel 的完整面板 `full_panel.dta`（Drive 的 full_panel 文件夹：<https://drive.google.com/drive/folders/1cwQiVRA47DKtOOs2zknxc6aH7VuUzqvJ>），放进 `../full_panel/data/clean/`。没有这个文件时，08 只输出月断裂率。09 从这个文件取伙伴 j 的 2017 年财务指标和每段关系的起始月，没有时跳过。

01、02 生成的 5 个中间文件（`entity.dta`、`successor.dta`、`tariff.dta`、`st_year.dta`、`firm.dta`）与 replication_jjyj2024 的完全相同，Drive 上不重复放，在 replication_jjyj2024 的数据文件夹里：<https://drive.google.com/drive/folders/1-Y3PqGCeSEIBhMWvMW64X74ipz_6Uw58>。

### `analysis_sample.dta` 的变量

| 变量 | 含义 |
|---|---|
| `focal`、`partner` | A 股企业 i、外国合作伙伴 j（FactSet company_id，已换 ID） |
| `pid`、`t`、`year` | 关系对、年月、年 |
| `break`、`break1`、`break2`、`break3` | 断裂；晚 1、2、3 个月断裂 |
| `first17` | 2017 年起的第一段关系（回归样本里都是 1） |
| `stkcd`、`sic`、`nnindcd` | A 股企业的股票代码、4 位 SIC、证监会行业代码 |
| `fcty`、`pcty` | A 股企业、伙伴的国家 |
| `tariff_i`、`fem` | A 股企业行业是否被美国加征关税；首次生效的月份 |
| `us`、`impact` | 伙伴是否美国企业；impact = tariff_i × us |
| `post` | 日历时间上的冲击后：加征行业为本行业首次生效月及以后，其余为 2018m7 及以后 |
| `postimpact` | post × impact，论文写法的 Post（只有处理组在冲击后为 1） |
| `us_post`、`us_tariff` | us × post、us × tariff_i（第 (4) 列三重差分用） |
| `size_i` … `growth_i` | A 股企业 2017 年的 Size、Lev、ROA、ATO、Growth（未缩尾） |
| `w_size_i` … `w_growth_i` | 同上，在回归样本上按观测 1%/99% 缩尾 |
| `postsize` … `postgrowth` | postimpact × 缩尾后的 5 项（第 (2) 列的财务变量） |
| `firm_m` | A 股企业 × 月（第 (3)(4) 列的固定效应） |

`analysis_K/C/M.dta` 的变量相同，缩尾在各自的样本上做。`panel_monthly.dta` 没有 `w_`、`post` 开头的财务变量和 `firm_m`。

## 原始数据（Google Drive 的 raw 文件夹）

**链接：** https://drive.google.com/drive/folders/1ieybcINamNeTz5V4X50rfG9Mb_jVIqZy

与 replication_jjyj2024 是同一批文件，路径和字段见 [../replication_jjyj2024/DATA.md](../replication_jjyj2024/DATA.md)。合作关系用的是 `relationship.csv` 里 `rel_type` 以 `PARTNER-` 开头的记录。
