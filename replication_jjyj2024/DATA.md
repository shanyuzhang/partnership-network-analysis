# 数据说明

数据不放在 GitHub 上，清洗好的数据和原始数据都在 Google Drive。原始数据下载后按下面的路径放好即可。

## 清洗好的数据（Google Drive）

**链接：** https://drive.google.com/drive/folders/1-Y3PqGCeSEIBhMWvMW64X74ipz_6Uw58

（它在 Drive 文件夹 `partnership-network-analysis` 下，与本仓库的文件夹一一对应：<https://drive.google.com/drive/folders/1hjU2et_KQtK56xQwNDDA7rtqlkjIK7-0>）

把下载的文件放进本文件夹的 `data/clean/`，再把 `code/run_all.do` 里的 `local clean 1` 改成 `local clean 0`，运行 `do code/run_all.do`，就只跑 04–06（表 2、附表 3、图 1、附图 1）。

| 文件 | 内容 | 观测值 × 变量 | 用在 |
|---|---|---:|---|
| `analysis_sample.dta` | 回归样本：2017m1–2019m12，每对企业只看 2017 年起的第一段关系，控制变量已在样本上缩尾 | 83,674 × 41 | 04、06 |
| `panel_monthly.dta` | 2017m1–2020m6 的关系对 × 月面板，已做全部样本筛选，不限第一段 | 103,834 × 31 | 05 |
| `entity.dta` | FactSet 公司信息，每家公司一行：名称、国家、ISIN、CUSIP 前 8 位、A 股代码、注销季度 | 662,631 × 9 | 02 |
| `successor.dta` | 换 ID 对照表：旧 company_id → 新 company_id | 13,011 × 2 | 03 |
| `tariff.dta` | 美国加征关税的 SIC 行业及首次生效的月份 | 436 × 2 | 03 |
| `st_year.dta` | A 股企业 × 年（2016–2019）：当年是否有 ST 交易日 | 13,835 × 3 | 03 |
| `firm.dta` | 每家 FactSet 公司一行：A 股代码、国家、SIC、2017 年 5 项财务指标、CSMAR 信息 | 662,631 × 13 | 03 |

前两个是分析用的数据。后五个是 01、02 生成的中间文件，放上来方便核对清洗的每一步，只跑回归用不到；其中 `entity.dta`、`firm.dta` 覆盖 FactSet 的全部 662,631 家公司，所以比较大。

### `analysis_sample.dta` 的变量

| 变量 | 含义 |
|---|---|
| `focal`、`partner` | 中国供应商 i、外国客户 j（FactSet company_id，已换 ID） |
| `pid`、`t`、`year` | 关系对、年月、年 |
| `break`、`break1`、`break2`、`break3` | 断裂；晚 1、2、3 个月断裂 |
| `first17` | 2017 年起的第一段关系（回归样本里都是 1） |
| `stkcd`、`sic`、`nnindcd` | 供应商的 A 股代码、4 位 SIC、证监会行业代码 |
| `fcty`、`pcty` | 供应商、客户的国家 |
| `tariff_i`、`fem` | 供应商行业是否被美国加征关税；首次生效的月份 |
| `us`、`impact` | 客户是否美国企业；Impact |
| `post_e`、`Post` | 日历时间上是否已到冲击月；论文写法的 Post（只有处理组在冲击后为 1，回归用这个） |
| `size_i` … `growth_j` | 两边 2017 年的 Size、Lev、ROA、ATO、Growth（未在回归样本上缩尾） |
| `w_size_i` … `w_growth_j` | 同上，在回归样本上按观测 1%/99% 缩尾，回归用这一组 |

`panel_monthly.dta` 的变量相同，只是没有 `w_` 开头的 10 个。

## 原始数据（Google Drive 的 raw 文件夹）

**链接：** https://drive.google.com/drive/folders/1ieybcINamNeTz5V4X50rfG9Mb_jVIqZy

里面的 `factset/`、`other/` 对应下表的 `data/raw/factset/`、`data/raw/other/`。默认放在下面的路径。放在别处时，新建 `code/00_config_local.do` 改路径（写法见 `code/00_config.do` 开头的说明）；文件名不同时，在 `code/00_config.do` 里改 `F_REL`、`F_ENT`、`F_WS`、`F_CO`、`F_TRD`、`F_TARIFF`。

| 放在 | 文件 | 内容 | 用到的字段 |
|---|---|---|---|
| `data/raw/factset/` | `relationship.csv`（约 1.2 GB） | FactSet Revere 供应链关系，每个记录版本一行；记录截至 2024-08-24 | `start_`、`end_`、`id`、`rel_type`、`source_company_id`、`target_company_id` |
| `data/raw/factset/` | `w9tvmpxavuvayoeq.csv`（约 660 MB） | FactSet Revere 公司信息，每个公司版本一行 | `start_`、`end_`、`name`、`active`、`cusip`、`isin`、`company_id`、`country`、`home_region`、`ticker_exchange` |
| `data/raw/other/` | `bdgq7ifz2pc6rkqd.csv`（约 57 MB） | Worldscope 年度数据，2015–2019 年 | `code`、`year_`、`item1001`、`item2999`、`item3051`、`item3251`、`item6004`、`item6008`、`item7021`、`item7230`、`item8326` |
| `data/raw/other/` | `TRD_Co.csv` | CSMAR 公司文件 | `Stkcd`、`Listdt`、`Nnindcd`、`Markettype` |
| `data/raw/other/` | `TRD_Dalyr.csv`、`TRD_Dalyr1.csv`、`TRD_Dalyr2.csv`、`TRD_Dalyr3.csv` | CSMAR 日个股回报率文件，2016–2019 年 | `Stkcd`、`Trddt`、`Trdsta` |
| `data/raw/other/` | `sic_code.csv` | 美国四轮加征关税涉及的 4 位 SIC 行业及生效日期，与论文附表 1 一致 | `effective_date`、`sic_code` |
