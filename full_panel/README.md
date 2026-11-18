# 完整面板（供应链 + 合作关系）

这是 [replication_jjyj2024](../replication_jjyj2024/) 和 [partnership_break](../partnership_break/) 用的同一套清洗，只是不截时间窗口、不做样本筛选，得到的完整面板。面板覆盖 A 股企业与境外企业（含港澳台）的全部供应链关系和合作关系，每个关系每个月一行，从 2016 年 1 月到 2024 年 7 月。两个文件夹的回归样本都是它的子集，用 `s_` 开头的变量可以直接取出来，已逐行逐变量核对过，完全一致。

数据放在 Google Drive，见 [DATA.md](DATA.md)。

| 内容 | 输出 |
|---|---|
| 完整面板 | `data/clean/full_panel.dta`、`full_panel.parquet`、`full_panel.csv`（不进仓库，在 Drive 上） |
| 变量说明 | `data/clean/full_panel_codebook.csv`：68 个变量，中英文对照（Drive 上也有）；中文说明见 [DATA.md](DATA.md) |
| 规模 | `output/tables/full_panel_summary.csv`（按关系类型）、`full_panel_by_year.csv`（按关系类型 × 年） |
| 与两个文件夹样本的核对 | `output/tables/check_samples.csv` |

## 面板是什么

| | |
|---|---|
| 一行 | A 股企业 i × 境外企业 j × 关系类型 `rel` × 月。只有关系存在的月份才有一行（非平衡面板） |
| `rel` | `supply_out`：供应链，i 是供应商、j 是客户（论文研究的方向）<br>`supply_in`：供应链，j 是供应商、i 是客户<br>`partnership`：合作关系，不分方向 |
| A 股企业 i | FactSet 里任一版本的上市代码是 60/68xxxx（上交所）或 00/30xxxx（深交所）的公司 |
| 境外企业 j | 国家不是中国内地的公司，含港澳台。国家未知（`pcty` 为空）和只有离岸注册地（`pcty` = `OFF`）的公司也保留。与中国内地企业的关系不在面板里 |
| 时间 | 2016m1–2024m7。2016m1 以前开始的关系从 2016m1 算起。FactSet 记录截至 2024-08-24，2024m8 只用来判断 2024m7 是否断裂 |

清洗规则与两个文件夹完全相同（01、02 是同一份代码）：
- 同一记录 ID 的前后版本相隔 7 天以内，算同一段关系；
- 某月里任意一天关系有效，这个月就算存在；`break` = 本月存在、下个月不存在；
- 已注销的旧 company_id 换成新 ID；
- 合作关系不分方向，按 FactSet 子类型分成知识（K）、资本（C）、市场（M）三类。

两个文件夹的样本筛选在这里都只是变量，不删行：
- 是否 CSMAR 确认的 A 股（`fA`）、是否金融业（`fin`）、是否 2018 年及以后上市（`late`）、当年是否 ST（`st_y`）；
- 能否对上 SIC（`tariff_i` 是否缺失）、2017 年财务指标是否齐全（`xi`、`xj`）；
- 对方国家（`pcty`）、是否 2017 年起的第一段（`first17`）。

## 规模

| `rel` | 行（关系 × 月） | 关系 | 对方是美国企业 | 处理组（`impact` = 1） | A 股企业 | 境外企业 | 断裂 |
|---|---:|---:|---:|---:|---:|---:|---:|
| 合计 | 1,136,930 | 50,587 | 12,202 | 6,723 | 4,264 | 17,693 | 31,801 |
| supply_out | 667,632 | 30,411 | 6,791 | 4,287 | 3,340 | 11,374 | 17,840 |
| supply_in | 242,226 | 10,681 | 2,949 | 1,259 | 2,361 | 5,466 | 7,522 |
| partnership | 227,072 | 9,495 | 2,462 | 1,177 | 2,621 | 5,472 | 6,439 |

- “关系”指一对企业的一种关系（`rel` × i × j）。50,587 个关系涉及 46,598 对企业，因为同一对企业可以既有供应链关系又有合作关系。
- 关系中间断开过、后来又出现，算新的一段（`run`）：共 53,893 段，其中 3,131 个关系不止一段。
- 按关系计，对方所在地：美国 12,202，港澳台 8,791，其他国家 27,946，只有离岸注册地 958，未知 690。
- 每类关系每年的行数、关系数、断裂数和月断裂率见 `output/tables/full_panel_by_year.csv`。

## 两个文件夹的样本

| 变量 | 对应文件 | 条件 | 行数 |
|---|---|---|---:|
| `s_jjyj_panel` | replication_jjyj2024 的 `panel_monthly.dta`（图 1） | `rel` = supply_out；共同条件；`xj` = 1；`stkcd_j` 为空；2017m1–2020m6 | 103,834 |
| `s_jjyj` | replication_jjyj2024 的 `analysis_sample.dta`（表 2 等） | `s_jjyj_panel` = 1，再加 t ≤ 2019m12、`first17` = 1 | 83,674 |
| `s_pt_panel` | partnership_break 的 `panel_monthly.dta`（图 1） | `rel` = partnership；共同条件；2017m1–2020m6 | 50,852 |
| `s_pt` | partnership_break 的 `analysis_sample.dta` | `s_pt_panel` = 1，再加 t ≤ 2019m12、`first17` = 1 | 42,332 |
| `s_pt_K`、`s_pt_C`、`s_pt_M` | partnership_break 的 `analysis_K.dta`、`analysis_C.dta`、`analysis_M.dta` | `rel` = partnership；共同条件；`pt_K` = 1、`first17_K` = 1（C、M 同理）；2017m1–2019m12 | 18,896、22,860、1,937 |

共同条件：`fA` = 1、`fin` = 0、`late` = 0、`st_y` ≠ 1、`tariff_i` 不缺失、`xi` = 1，`pcty` 不为空也不是 `OFF`。

`05_check_samples.do` 把这 7 个样本从完整面板里取出来，按 focal、partner、t 与两个文件夹的原文件一一对上，逐个比较原文件里的变量。结果：7 个样本行数都相同，没有对不上的行，也没有不一致的值（`output/tables/check_samples.csv`）。比较时有三点处理：
- 变量名换成原文件的：replication_jjyj2024 里 `post` 叫 `post_e`，`postimpact` 叫 `Post`；
- 回归样本里有几个变量不在完整面板里：在样本内缩尾的 `w_` 变量、`post*` 交互项、`us_post`、`us_tariff`、`firm_m`。这些变量用两个文件夹里同样的代码，在取出的行上重新生成；
- `pid` 是各自编号的，不比较。三大类样本的 `break`、`first17` 用这一类自己的 `break_K`、`first17_K` 等；三大类样本里的 break1–3 完整面板没有，也不比较。

## 用的时候要注意

1. 只有关系存在的月份才有一行。断裂之后、重新出现之前没有行，所以算断裂率时，分母是当月存在的关系。
2. 2024m7 的 `break` 根据 2024m8 是否存在来判断。`break1`、`break2`、`break3` 要看到后面几个月，所以数据最后 1、2、3 个月为缺失。
3. `run_start` = 2016m1 的段，可能更早就开始了，因为面板从 2016m1 起。
4. 财务变量（Size、Lev、ROA、ATO、Growth）只有 2017 年一个值，与论文一样以 2017 年为基期，不随时间变化。Worldscope 只下载了 2015–2019 年；`st_y` 只有 2016–2019 年，其他年份为缺失。
5. `tariff_i` 要先有 i 的 SIC。4,264 家 A 股企业中 3,721 家有 SIC，其余企业的 `tariff_i`、`impact`、`post`、`postimpact` 为缺失。
6. 中国移动（600941）在 FactSet 里的国家是香港。它作为 i 是 A 股企业；作为 j 时国家是 HK，所以也在面板里（381 个关系）。供应链样本要求对方没有 A 股代码，合作关系样本没有这个要求，两个文件夹原来就是这样。
7. 两个文件夹的 7 个样本里没有的部分，生成规则相同，但没有单独核对过：supply_in、2016 年和 2020m7 以后的月份、国家未知或只有离岸注册地的境外企业。partnership_break 的三大类描述统计（`08_types_desc.do`）用到了其中合作关系的部分。
8. partnership_break 的检查发现，2018 年 7–9 月和 2019 年 10–12 月的断裂高峰，主要来自 FactSet 对部分 A 股企业合作记录的整批结束；2017 年 7–9 月（加征关税之前）也有同样的高峰。供应链关系没有做过同样的检查。看断裂随时间的变化时要留意这一点。
9. `pid` 与两个文件夹里的 `pid` 编号不同；识别一个关系用 `rel`、`focal`、`partner`。

## 运行

需要 Stata 17 及以上。生成 Parquet 另外需要 Python（pandas、pyarrow）。Stata 里先 `cd` 到本文件夹，再运行：

```stata
cd "<仓库位置>/full_panel"
do code/run_all.do
```

然后在本文件夹里生成 Parquet 和 CSV 压缩包：

```bash
python3 code/04b_to_parquet.py data/clean/full_panel.dta data/clean/full_panel.parquet
```

```bash
cd data/clean && zip -9 full_panel_csv.zip full_panel.csv
```

- 原始数据与另外两个文件夹是同一批文件，按 [../replication_jjyj2024/DATA.md](../replication_jjyj2024/DATA.md) 放进 `data/raw/`；放在别处时，新建 `code/00_config_local.do` 改路径（不会上传）。
- 已有 01、02 生成的 5 个中间文件时（Drive 上 replication_jjyj2024 文件夹里有），可以放进 `data/clean/`，把 `code/run_all.do` 里的 `local clean 1` 改成 `local clean 0`，从 03 开始跑。03 仍然需要原始的 `relationship.csv`。
- 05 要读另外两个文件夹的 `data/clean/`；没有这些文件时，`run_all.do` 会跳过 05。

从原始数据完整跑一遍（01–05）约一分半钟。

## 文件

```
full_panel/
├── README.md
├── DATA.md                     数据：Drive 链接、文件、变量说明
├── code/
│   ├── 00_config.do            路径、文件名、时间常量
│   ├── 01_clean_entities.do    FactSet 公司信息、换 ID 对照表（与另外两个文件夹相同）
│   ├── 02_clean_firms.do       加征关税行业、ST、CSMAR、Worldscope 2017 年财务指标（与另外两个文件夹相同）
│   ├── 03_full_panel.do        供应链 + 合作关系 -> full_panel.dta；规模表
│   ├── 04_export.do            full_panel.csv、full_panel_codebook.csv
│   ├── 04b_to_parquet.py       full_panel.parquet
│   ├── 05_check_samples.do     与两个文件夹的 7 个样本逐行逐变量核对
│   └── run_all.do
└── output/tables/              full_panel_summary.csv、full_panel_by_year.csv、check_samples.csv
```
