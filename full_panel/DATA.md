# 数据说明

完整面板不放在 GitHub 上，放在 Google Drive；原始数据与另外两个文件夹是同一批文件，也在 Drive 上。

## 完整面板（Google Drive）

**链接：** https://drive.google.com/drive/folders/1cwQiVRA47DKtOOs2zknxc6aH7VuUzqvJ

（它在 Drive 文件夹 `partnership-network-analysis` 下，与本仓库的文件夹一一对应：<https://drive.google.com/drive/folders/1hjU2et_KQtK56xQwNDDA7rtqlkjIK7-0>）

三个数据文件的内容相同，都是 1,136,930 行 × 68 个变量，按需要选一个：

| 文件 | 大小 | 用法 |
|---|---:|---|
| `full_panel.parquet` | 5.3 MB | Python（`pandas.read_parquet`）、R（`arrow::read_parquet`）。文件最小，交给 AI 工具分析时用这个 |
| `full_panel.dta` | 212 MB | Stata，带中文变量标签 |
| `full_panel_csv.zip` | 10 MB | 解压后是 `full_panel.csv`（397 MB，UTF-8，逗号分隔）。行数超过 Excel 的上限（1,048,576 行），Excel 打不全 |
| `full_panel_codebook.csv` | 10 KB | 68 个变量的说明：变量名、Stata 存储类型、中文说明、英文说明 |

三种格式的写法：
- `rel`：.dta 里是有值标签的数字（1 = supply_out，2 = supply_in，3 = partnership），parquet 和 CSV 里是文字。`pt_types` 也一样。
- 年月：.dta 里是 Stata 的月份（如 2018m7）。parquet 里是日期，取当月 1 号；CSV 里写成 2018-07。
- 缺失值：.dta 里是 `.`，parquet 里是 null，CSV 里为空。

01、02 生成的 5 个中间文件（`entity.dta`、`successor.dta`、`tariff.dta`、`st_year.dta`、`firm.dta`）与另外两个文件夹的完全相同，不重复放；它们在 replication_jjyj2024 的数据文件夹里：<https://drive.google.com/drive/folders/1-Y3PqGCeSEIBhMWvMW64X74ipz_6Uw58>。

## 变量

一行是 A 股企业 i × 境外企业 j × 关系类型 `rel` × 月，只有关系存在的月份才有一行。英文说明见 `full_panel_codebook.csv`。

**识别与时间**

| 变量 | 含义 |
|---|---|
| `rel` | 关系类型：supply_out = 供应链，i 是供应商、j 是客户（论文研究的方向）；supply_in = 供应链，j 是供应商、i 是客户；partnership = 合作关系（不分方向） |
| `pid` | 关系编号 = `rel` × `focal` × `partner`（与另外两个文件夹里的 `pid` 编号不同） |
| `focal`、`partner` | i、j 的 FactSet company_id（已把注销的旧 ID 换成新 ID） |
| `t`、`year` | 年月、年 |

**A 股企业 i**

| 变量 | 含义 |
|---|---|
| `stkcd`、`name_i` | 6 位 A 股代码；FactSet 里的公司名 |
| `fcty` | 国家：FactSet 的地址国家 `country`，为空时用 `home_region`；KY、VG、BM、XZ 只是注册地，记为 OFF |
| `sic` | 4 位 SIC（Worldscope；优先 2017 年，没有就用最近的一年） |
| `nnindcd` | 证监会 2012 版行业代码（CSMAR；J 开头是金融业） |
| `in_csmar`、`markettype`、`listd` | 代码在 CSMAR 公司文件里；CSMAR 市场类型（1 上证 A 股，不含科创板；4 深证 A 股，不含创业板；16 创业板；32 科创板；2、8 是 B 股，64 是北证 A 股）；上市日期 |
| `fA` | CSMAR 确认的 A 股：`in_csmar` = 1 且 `markettype` 是 1、4、16、32 |
| `fin`、`late` | 金融业；2018 年及以后上市 |
| `st_y` | 当年有 ST 交易日（CSMAR 交易状态）；只有 2016–2019 年，其他年份为缺失 |

**境外企业 j**

| 变量 | 含义 |
|---|---|
| `name_j` | FactSet 里的公司名 |
| `pcty` | 国家，口径同 `fcty`；空 = 未知，OFF = 只有离岸注册地 |
| `sic_j` | 4 位 SIC（Worldscope） |
| `stkcd_j` | A 股代码（只有中国移动 600941 有，它在 FactSet 里的国家是香港） |

**关系的状态**

| 变量 | 含义 |
|---|---|
| `run` | 这个关系的第几段（连续存在的月份算一段，从 2016m1 起数） |
| `run_start`、`run_end` | 这一段的第一个月、最后一个月。`run_start` = 2016m1 表示 2016m1 或更早就已存在；`run_end` = 2024m7 且 `break` = 0 表示到数据截止仍存续 |
| `break` | 本月存在、下个月不存在 |
| `break1`、`break2`、`break3` | 晚 1、2、3 个月断裂（下个月存在、再下个月不存在，依此类推）；数据最后几个月判断不了，为缺失 |
| `first17` | 这一段是这个关系 2017m1 起的第一段（2017m1 时已在持续的也算）；两个文件夹的回归样本只用 `first17` = 1 |
| `src_i`、`src_j` | 本月有以 i（j）为 source 的 FactSet 记录 |

**合作关系的类型**（只对 `rel` = partnership 有值，供应链的行为缺失）

| 变量 | 含义 |
|---|---|
| `pt_K`、`pt_C`、`pt_M`、`pt_U` | 本月有知识类（RESCOLB、TECHNGY、LICENIN、LICENOT、PLICENS、INTPROD）、资本类（INVESTO、EINVEST、JVENTUR）、市场类（DISTRIB、MARKTNG、MANUFAC）、未归类（子类型 NA）的合作 |
| `pt_types` | 本月有效的 FactSet 子类型，空格分隔 |
| `break_K`、`break_C`、`break_M` | 这一类本月存在、下个月不存在（这对企业别的类型的合作还在，也算这一类断裂）；只在这一类本月存在时有值 |
| `first17_K`、`first17_C`、`first17_M` | 这一类 2017m1 起的第一段 |

**处理组与冲击后**

| 变量 | 含义 |
|---|---|
| `tariff_i` | i 所在 SIC 行业被美国加征关税（`sic_code.csv`，与论文附表 1 一致）；i 的 SIC 未知时为缺失 |
| `fem` | i 所在行业首次加征关税生效的月份 |
| `us` | j 是美国企业 |
| `impact` | `tariff_i` × `us`（处理组） |
| `post` | 日历时间上的冲击后：加征行业为本行业首次生效月及以后，其余行业为 2018m7 及以后；`tariff_i` 缺失时为缺失 |
| `postimpact` | `post` × `impact`，即论文写法的 Post：只有处理组在冲击后为 1（replication_jjyj2024 里叫 `Post`） |

**2017 年财务指标**（i、j 各一套，后缀 `_i`、`_j`；Worldscope 字段号）

| 变量 | 含义 |
|---|---|
| `size_i`、`size_j` | ln(总资产美元 7230 / 1000 万) |
| `lev_i`、`lev_j` | (短期债务 3051 + 长期债务 3251) / 总资产 2999 |
| `roa_i`、`roa_j` | ROA（8326），用小数 |
| `ato_i`、`ato_j` | 营业收入 1001 / 总资产 2999 |
| `growth_i`、`growth_j` | 2017 年营业收入 / 2016 年营业收入 − 1 |
| `xi`、`xj` | 5 项都不缺失 |

Lev、ROA、ATO、Growth 已在 Worldscope 全部公司的 2017 年截面上按 1%/99% 缩尾。两个文件夹的回归还要在回归样本上再缩尾一次（`w_` 开头的变量），这一步只在取出样本后才能做，完整面板里没有。

**样本标记**（条件见 [README.md](README.md)；已逐行核对与原文件一致）

| 变量 | 在哪个文件里 |
|---|---|
| `s_jjyj_panel`、`s_jjyj` | replication_jjyj2024 的 `panel_monthly.dta`、`analysis_sample.dta` |
| `s_pt_panel`、`s_pt` | partnership_break 的 `panel_monthly.dta`、`analysis_sample.dta` |
| `s_pt_K`、`s_pt_C`、`s_pt_M` | partnership_break 的 `analysis_K.dta`、`analysis_C.dta`、`analysis_M.dta`（因变量用 `break_K`、`break_C`、`break_M`） |

## 原始数据（Google Drive 的 raw 文件夹）

**链接：** https://drive.google.com/drive/folders/1ieybcINamNeTz5V4X50rfG9Mb_jVIqZy

与 replication_jjyj2024 是同一批文件，路径和字段见 [../replication_jjyj2024/DATA.md](../replication_jjyj2024/DATA.md)。用到 `relationship.csv` 里 `rel_type` 为 CUSTOMER、SUPPLIER 和以 `PARTNER-` 开头的记录。
