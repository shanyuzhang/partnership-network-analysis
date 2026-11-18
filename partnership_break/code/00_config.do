* ==========================================================================================
* 00_config.do —— 路径、文件名、时间常量（其他 do 文件开头都会先运行它）
*
* 用法：Stata 里先 cd 到 partnership_break 文件夹，再 do code/run_all.do（或单独运行某一步）。
*   - 原始数据默认放在 data/raw/factset/ 和 data/raw/other/（见 DATA.md），与 replication_jjyj2024 用的是同一批文件。
*   - 清洗后的数据写到 data/clean/，表和图写到 output/。
*   - 原始数据放在别处时，新建 code/00_config_local.do（已写进 .gitignore，不会上传），在里面改路径，例如：
*         global RAW_FACTSET "D:/data/factset"
*         global RAW_OTHER   "D:/data/other"
*
* 需要：Stata 17 及以上；reghdfe、ftools、estout（ssc install reghdfe / ftools / estout）
* ==========================================================================================
version 17
set more off
set varabbrev off

* 本文件夹（partnership_break）的位置：当前工作目录（每次都重设，免得同一个 Stata 窗口先跑过别的文件夹时写错地方）
global REPO "`c(pwd)'"

* ---- 数据和输出的位置 ----
global RAW_FACTSET "$REPO/data/raw/factset"   // FactSet Revere
global RAW_OTHER   "$REPO/data/raw/other"     // Worldscope、CSMAR、加征关税行业清单
global CLEAN       "$REPO/data/clean"         // 01-03 写，04-08 读
global OUT         "$REPO/output"

* ---- 原始文件名 ----
global F_REL    "relationship.csv"            // FactSet Revere 关系记录（合作、客户、供应商等），每个记录版本一行
global F_ENT    "w9tvmpxavuvayoeq.csv"        // FactSet Revere 公司信息，每个公司版本一行
global F_WS     "bdgq7ifz2pc6rkqd.csv"        // Worldscope 年度财务数据，2015-2019，全部国家
global F_CO     "TRD_Co.csv"                  // CSMAR 公司文件（市场类型、上市日期、证监会行业）
global F_TRD    "TRD_Dalyr TRD_Dalyr1 TRD_Dalyr2 TRD_Dalyr3"   // CSMAR 日个股回报率文件 2016-2019（用交易状态 Trdsta 判断 ST）
global F_TARIFF "sic_code.csv"                // 美国加征关税的 SIC 行业及生效日期（与论文附表 1 一致）

* ---- 本机路径（可选，不上传）----
capture confirm file "$REPO/code/00_config_local.do"
if !_rc do "$REPO/code/00_config_local.do"

capture mkdir "$REPO/data"
capture mkdir "$CLEAN"
capture mkdir "$OUT"
capture mkdir "$OUT/tables"
capture mkdir "$OUT/figures"
capture mkdir "$OUT/logs"

* ---- 时间常量（月度）----
global M0   = tm(2016m1)    // 关系段从这个月开始展开（比样本起点早一年，2017 年起的“第一段”才判断得准）
global MMAX = tm(2024m7)    // 数据里最后一个完整月（FactSet 关系记录截至 2024-08-24）
global MEXT = tm(2024m8)    // END_DATE 为空（至今有效）的关系，记为存续到下载月
