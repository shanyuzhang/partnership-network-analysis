* ==========================================================================================
* 01_clean_entities.do —— 第一步清洗：FactSet 公司信息与换 ID 对照表
*
* 输入：$RAW_FACTSET/$F_ENT   FactSet Revere 公司信息（每个公司版本一行）
* 输出：$CLEAN/entity.dta     每家 FactSet 公司一行：名称、国家、ISIN、CUSIP8、A 股代码、注销季度
*       $CLEAN/successor.dta  换 ID 对照表：旧 company_id -> 新 company_id
*
* 为什么要换 ID：FactSet 在公司合并、改名、重组时会注销旧 ID、启用新 ID，但数据里没有新旧 ID 的对应表。
* 不处理的话，旧 ID 的关系会在注销那个月“断裂”，新 ID 的关系又像新建立的，制造假断裂。这里用两条规则近似：
*   规则 1（名称或 ISIN）：旧 ID 已注销；另一个 ID 的标准化名称相同（国家相同或一方未知），或 ISIN 相同；
*          新 ID 注销得更晚或没有注销。一个旧 ID 只有唯一候选时才改写。
*   规则 2（只用 ISIN，补规则 1 的漏网）：规则 1 在一个旧 ID 有多个候选时整个放弃。例如沃尔玛 2019 年 2 月
*          换 ID（旧 10953 -> 新 122334162，ISIN 都是 US9311421039），规则 1 漏掉，那个月会多出 23 个假断裂。
*          规则 2：ISIN 相同且候选唯一、新 ID 注销更晚或没有注销。规则 1 已有的旧 ID 不变，只补规则 1 没有的。
*   最后处理连环换 ID（新 ID 本身也被换掉）。
* ==========================================================================================
clear all
do "code/00_config.do"
capture log close l01
log using "$OUT/logs/01_clean_entities.log", replace text name(l01)

* ==========================================================================================
* 1. 公司信息：每家公司一行
* ==========================================================================================
import delimited using "$RAW_FACTSET/$F_ENT", varnames(1) colrange(1:20) stringcols(_all) encoding(utf-8) clear
keep start_ end_ name active cusip isin company_id country home_region ticker_exchange
destring company_id, replace force
drop if company_id == .
gen ds = date(start_, "YMD")
gen de = date(end_,   "YMD")
replace de = . if de > td(31dec2099)            // 原始文件用 4000-01-01 表示至今有效
format ds de %td

* A 股代码：任一版本的上市代码为 60/68xxxx-SHG 或 00/30xxxx-SHE，取最近的那个
gen byte a_v = ustrregexm(ticker_exchange, "^(60|68)[0-9]{4}-SHG$") | ustrregexm(ticker_exchange, "^(00|30)[0-9]{4}-SHE$")
gen str6 a_code = substr(ticker_exchange, 1, 6) if a_v
gen byte   neg_a  = -a_v
gen double neg_ds = -ds
sort company_id neg_a neg_ds, stable             // 同一天的版本保持原始文件顺序，结果可重复
by company_id: gen str6 stkcd = a_code[1]
drop neg_a neg_ds

* 注销时间：第一次 active = N，或者全部版本都已结束
gen double inact_d = ds if active == "N"
gen byte   is_cur  = de == .
bys company_id: egen double gone1   = min(inact_d)
bys company_id: egen byte   anycur  = max(is_cur)
bys company_id: egen double lastend = max(de)
gen double gone_d = min(gone1, cond(anycur, ., lastend))

* 每家公司保留 2018-07-01 有效的那个版本，没有就保留最新的版本
gen byte v18 = ds <= td(01jul2018) & (de > td(01jul2018) | de == .)
sort company_id v18 ds, stable                   // 同一天的版本保持原始文件顺序，结果可重复
by company_id: keep if _n == _N
replace isin  = upper(strtrim(isin))
replace cusip = upper(strtrim(cusip))
replace isin  = "" if strlen(isin)  < 12
replace cusip = "" if strlen(cusip) < 8
gen cusip8 = substr(cusip, 1, 8)
gen gone_q = qofd(gone_d)
format gone_q %tq

* 国家：地址国家为空时用 home_region；开曼、英属维尔京、百慕大、XZ 只是注册地，记为 OFF（回归前剔除）
replace home_region = upper(strtrim(home_region))
gen str3 country2 = country
replace country2 = home_region if country2 == ""
replace country2 = "OFF" if inlist(country2, "KY", "VG", "BM", "XZ")

* 标准化公司名（只用于识别换 ID）：小写、去括号内容和标点、去掉 Inc/Ltd/Corp 等后缀
gen nn = ustrlower(name)
replace nn = ustrregexra(nn, "\([^)]*\)", " ")
replace nn = ustrregexra(nn, "/[^/]*/", " ")
replace nn = ustrregexra(nn, "s\.p\.a\.|s\.a\.", " ")
replace nn = ustrregexra(nn, "[^a-z0-9]+", " ")
replace nn = " " + nn + " "
foreach w in co ltd limited inc corp corporation company group holding holdings plc llc lp sa spa ag gmbh kg the {
    replace nn = subinstr(nn, " `w' ", " ", .)
    replace nn = subinstr(nn, " `w' ", " ", .)
}
replace nn = strtrim(stritrim(nn))

keep company_id name nn country country2 isin cusip8 gone_q stkcd
compress
save "$CLEAN/entity.dta", replace
di as txt "FactSet 公司数 = " _N
count if stkcd != ""
di as txt "其中有 A 股代码 = " r(N)

* ==========================================================================================
* 2. 换 ID 规则 1：标准化名称相同或 ISIN 相同，候选唯一
* ==========================================================================================
use "$CLEAN/entity.dta", clear
keep if strlen(nn) >= 4
keep company_id nn country2 gone_q
rename (company_id country2 gone_q) (new c_new gq_new)
tempfile cand_nn
save `cand_nn'

use "$CLEAN/entity.dta", clear
keep if isin != ""
keep company_id isin gone_q
rename (company_id gone_q) (new gq_new)
tempfile cand_isin
save `cand_isin'

use "$CLEAN/entity.dta", clear
keep if gone_q < .
keep company_id nn country2 isin gone_q
rename (company_id country2 gone_q) (old c_old gq_old)
preserve
    keep if strlen(nn) >= 4
    joinby nn using `cand_nn'
    keep if new != old & (gq_new == . | gq_new > gq_old) ///
        & (c_old == c_new | inlist(c_old, "", "OFF") | inlist(c_new, "", "OFF"))
    keep old new
    tempfile m_name
    save `m_name'
restore
keep if isin != ""
joinby isin using `cand_isin'
keep if new != old & (gq_new == . | gq_new > gq_old)
keep old new
append using `m_name'
duplicates drop
bys old: keep if _N == 1                         // 一个旧 ID 只有唯一候选时才改写
di as txt "规则 1：旧 ID 数 = " _N
tempfile r1
save `r1'
* 连环换 ID（规则 1 内部做一遍）
rename (old new) (new new2)
tempfile r1b
save `r1b'
use `r1', clear
merge m:1 new using `r1b', keep(master match) nogen
replace new = new2 if new2 < . & new2 != old
keep old new
gen byte src = 1
tempfile rule1
save `rule1'

* ==========================================================================================
* 3. 换 ID 规则 2：只用 ISIN，补规则 1 因候选不唯一而放弃的旧 ID
* ==========================================================================================
use "$CLEAN/entity.dta", clear
keep if isin != ""
keep company_id isin gone_q
tempfile ent
save `ent'
keep if gone_q < .
rename (company_id gone_q) (old gq_old)
joinby isin using `ent'
rename (company_id gone_q) (new gq_new)
keep if new != old & (gq_new == . | gq_new > gq_old)
keep old new
duplicates drop
bys old: keep if _N == 1
gen byte src = 2

append using `rule1'
bys old (src): keep if _n == 1                   // 规则 1 已有的旧 ID 保持不变
count if src == 2
di as txt "规则 2 补充的旧 ID 数 = " r(N)

* 连环换 ID：新 ID 本身也被改写（做两遍）
forvalues pass = 1/2 {
    preserve
        keep old new
        rename (old new) (new new2)
        tempfile chain
        save `chain'
    restore
    merge m:1 new using `chain', keep(master match) nogen
    replace new = new2 if new2 < . & new2 != old
    drop new2
}
di as txt "例：沃尔玛（旧 10953 -> 新 122334162，ISIN 相同）由规则 2 补上"
format old new %12.0f
list old new src if old == 10953, noobs
rename (old new) (company_id company_id_new)
keep company_id company_id_new
sort company_id
compress
save "$CLEAN/successor.dta", replace
di as txt "换 ID 对照表：旧 ID 数 = " _N

log close l01
