* ==========================================================================================
* 03_full_panel.do —— 完整面板：A 股企业与境外企业的全部供应链、合作关系 x 月，2016m1-2024m7
*
* 输入：$RAW_FACTSET/$F_REL   FactSet Revere 关系记录
*       $CLEAN/successor.dta、entity.dta、firm.dta、tariff.dta、st_year.dta（01、02 生成）
* 输出：$CLEAN/full_panel.dta
*       $OUT/tables/full_panel_summary.csv   每类关系的行数、关系对数、企业数、断裂数
*       $OUT/tables/full_panel_by_year.csv   每类关系 x 年：行数、关系对数、断裂数、月断裂率
*
* 这是 replication_jjyj2024（供应链）和 partnership_break（合作关系）共用的“大面板”。清洗规则与两个文件夹的
* 03_clean_panel.do 完全相同，只是不截时间窗口、不做样本筛选：每条筛选条件都留成变量，s_ 开头的变量标出
* 两个文件夹的各个样本分别是哪些行（05_check_samples.do 逐行逐变量核对）。
*
*   观测单位   A 股企业 i x 境外企业 j x 关系类型 rel x 月；只有关系存在的月份才有一行（非平衡面板）
*   rel        1 supply_out   供应链：i 是供应商、j 是客户（论文的方向）
*              2 supply_in    供应链：j 是供应商、i 是客户
*              3 partnership  合作关系（不分方向）
*   A 股企业 i FactSet 任一版本的上市代码为 60/68xxxx-SHG 或 00/30xxxx-SHE 的公司（stkcd 非空）。是否 CSMAR 确认的
*              A 股、金融业、上市时间、当年 ST、能否对上 SIC、财务指标是否齐全，都留成变量，不做筛选
*   境外企业 j 国家不是中国内地（CN）的公司：港澳台、其他国家，以及国家未知（pcty 为空）、只有离岸注册地
*              （pcty = OFF）的公司。与中国内地企业的关系不在这个面板里
*   时间       2016m1-2024m7。2016m1 以前开始的关系从 2016m1 算起；FactSet 记录截至 2024-08-24，
*              2024m8 只用来判断 2024m7 是否断裂
*   关系段     同一记录 ID 的前后版本相隔 7 天以内视为同一段；某月里任意一天关系有效，这个月就算存在
*   断裂       break = 本月存在、下个月不存在；break1/2/3 = 再晚 1/2/3 个月断裂（数据末尾判断不了的为缺失）
*   换 ID      两边的旧 company_id 都换成新 company_id（01 生成的对照表）
* ==========================================================================================
clear all
do "code/00_config.do"
capture log close l03
log using "$OUT/logs/03_full_panel.log", replace text name(l03)

local SUBS RESCOLB TECHNGY LICENIN LICENOT PLICENS INTPROD INVESTO EINVEST JVENTUR DISTRIB MARKTNG MANUFAC NA

* ==========================================================================================
* 1. 关系记录 -> 关系段（同一记录 ID 前后版本相隔 <= 7 天视为同一段）
*    供应链（CUSTOMER、SUPPLIER）和合作关系（PARTNER-）一起处理。记录 ID 不跨类型（分别以 CUST-、SUPPL-、
*    PARTN- 开头），同一 ID 内记录的先后顺序与两个文件夹分别处理时相同，所以关系段完全一样
* ==========================================================================================
import delimited using "$RAW_FACTSET/$F_REL", varnames(1) colrange(1:6) stringcols(_all) clear
keep if inlist(rel_type, "CUSTOMER", "SUPPLIER") | substr(rel_type, 1, 8) == "PARTNER-"
destring source_company_id target_company_id, replace force
gen ds = date(start_, "YMD")
gen de = date(end_,   "YMD")
replace de = . if de > td(31dec2099)              // 远期日期表示至今有效
format ds de %td
drop if ds == . | source_company_id == . | target_company_id == .
drop if source_company_id == target_company_id
gen byte cur = de == .                            // 至今有效
keep id rel_type source_company_id target_company_id ds de cur
sort id ds de, stable                             // 同一天的版本保持原始文件顺序，结果可重复
gen double e2 = cond(cur, 99999, de)
by id: gen double runmax = e2 if _n == 1
by id: replace runmax = max(runmax[_n-1], e2) if _n > 1
by id: gen double gapdays = ds - runmax[_n-1] if _n > 1
by id: gen byte newsp = _n == 1 | gapdays > 7
by id: gen int spell = sum(newsp)
collapse (min) ds (max) e2 (first) rel_type src = source_company_id tgt = target_company_id, by(id spell)
gen byte cur = e2 == 99999
gen de = cond(cur, ., e2)
format ds de %td
drop e2
gen byte sc = inlist(rel_type, "CUSTOMER", "SUPPLIER")
di as txt "关系段（全库）：sc = 1 供应链，sc = 0 合作关系"
tab sc

* ==========================================================================================
* 2. 换 ID；从 A 股企业一方看，每段关系属于哪一类、对方是谁
*    CUSTOMER 记录：source 是供应商、target 是客户；SUPPLIER 记录相反
*    供应链：A 股企业是供应商记为 supply_out，是客户记为 supply_in（两方都是 A 股企业时各算一次）
*    合作关系不分方向：有 A 股代码的一方是 i，两方都有时取 source 一方（与 partnership_break 相同）
* ==========================================================================================
foreach s in src tgt {
    rename `s' company_id
    quietly merge m:1 company_id using "$CLEAN/successor.dta", keep(master match)
    quietly replace company_id = company_id_new if _merge == 3
    drop company_id_new _merge
    rename company_id `s'
}
drop if src == tgt
foreach s in src tgt {
    rename `s' company_id
    quietly merge m:1 company_id using "$CLEAN/firm.dta", keep(master match) nogen keepusing(stkcd country2)
    rename (company_id stkcd country2) (`s' stk_`s' cty_`s')
}
gen int ms = mofd(ds)
gen int me = cond(cur, $MEXT, mofd(de))
keep if me >= ms & me >= $M0 & ms <= $MMAX
replace ms = max(ms, $M0)
gen int mb = min(me, $MMAX + 1)
gen int nm = mb - ms + 1

gen long sup     = cond(rel_type == "CUSTOMER", src, tgt) if sc
gen long cus     = cond(rel_type == "CUSTOMER", tgt, src) if sc
gen str6 stk_sup = cond(rel_type == "CUSTOMER", stk_src, stk_tgt) if sc
gen str6 stk_cus = cond(rel_type == "CUSTOMER", stk_tgt, stk_src) if sc
gen str3 cty_sup = cond(rel_type == "CUSTOMER", cty_src, cty_tgt) if sc
gen str3 cty_cus = cond(rel_type == "CUSTOMER", cty_tgt, cty_src) if sc
gen str7 sub = substr(rel_type, 9, .) if !sc
gen str1 grp = cond(inlist(sub, "RESCOLB", "TECHNGY", "LICENIN", "LICENOT", "PLICENS", "INTPROD"), "K", ///
               cond(inlist(sub, "INVESTO", "EINVEST", "JVENTUR"), "C", ///
               cond(inlist(sub, "DISTRIB", "MARKTNG", "MANUFAC"), "M", "U"))) if !sc
tempfile seg
save `seg'

use if sc & stk_sup != "" & cty_cus != "CN" using `seg', clear
gen byte rel = 1
gen long focal   = sup
gen long partner = cus
tempfile v1
save `v1'

use if sc & stk_cus != "" & cty_sup != "CN" using `seg', clear
gen byte rel = 2
gen long focal   = cus
gen long partner = sup
tempfile v2
save `v2'

use if !sc & (stk_src != "" | stk_tgt != "") using `seg', clear
gen long focal   = cond(stk_src != "", src, tgt)
gen long partner = cond(stk_src != "", tgt, src)
keep if cond(stk_src != "", cty_tgt, cty_src) != "CN"
gen byte rel = 3
append using `v1' `v2'

label define rel 1 "supply_out" 2 "supply_in" 3 "partnership"
label values rel rel
gen byte src_i = src == focal
gen byte src_j = src == partner
foreach g in K C M U {
    gen byte g_`g' = grp == "`g'"
}
foreach s of local SUBS {
    gen byte d_`s' = sub == "`s'"
}
di as txt "A 股企业与境外企业的关系段："
tab rel

preserve
    keep if rel == 3
    keep focal partner grp ms nm
    tempfile ptsp
    save `ptsp'
restore

* ==========================================================================================
* 3. 关系段 -> 关系对 x 月（月内任一天有效即存在）；关系段编号、断裂、第一段
* ==========================================================================================
keep rel focal partner ms nm src_i src_j g_* d_*
gen long sid = _n
expand nm
bys sid: gen int t = ms + _n - 1
collapse (max) src_i src_j g_* d_*, by(rel focal partner t)
format t %tm
capture label drop rel
label define rel 1 "supply_out" 2 "supply_in" 3 "partnership"
label values rel rel

egen long pid = group(rel focal partner)
sort pid t
by pid: gen byte runstart = _n == 1 | t != t[_n-1] + 1
by pid: gen int  run      = sum(runstart)
by pid: gen byte break    = _n == _N | t[_n+1] != t + 1      // 本月存在、下个月不存在
replace break = 0 if t >= $MMAX + 1                         // 数据最后一个月之后无法判断
by pid: gen byte break1 = t[_n+1] == t + 1 & break[_n+1]  == 1
by pid: gen byte break2 = t[_n+1] == t + 1 & break1[_n+1] == 1
by pid: gen byte break3 = t[_n+1] == t + 1 & break2[_n+1] == 1
replace break1 = . if t > $MMAX - 1                         // 要看到再后面的月份才能判断
replace break2 = . if t > $MMAX - 2
replace break3 = . if t > $MMAX - 3
by pid: egen int r17 = min(cond(t >= tm(2017m1), run, .))
gen byte first17 = run == r17                               // 2017m1 起（含 2017m1 仍在持续）的第一段
bys pid run: egen int run_start = min(t)
bys pid run: egen int run_end   = max(t)
drop if t > $MMAX
replace run_end = min(run_end, $MMAX)
drop runstart r17
format run_start run_end %tm

* ---- 合作关系的三大类：每一类单独看存在与断裂（与 partnership_break 的三大类面板相同）----
tempfile full
save `full'
foreach g in K C M {
    use if grp == "`g'" using `ptsp', clear
    gen long sid = _n
    expand nm
    bys sid: gen int t = ms + _n - 1
    gen byte one = 1
    collapse (max) one, by(focal partner t)
    drop one
    egen long gid = group(focal partner)
    sort gid t
    by gid: gen byte rs = _n == 1 | t != t[_n-1] + 1
    by gid: gen int  rn = sum(rs)
    by gid: gen byte break_`g' = _n == _N | t[_n+1] != t + 1
    replace break_`g' = 0 if t >= $MMAX + 1
    by gid: egen int r17 = min(cond(t >= tm(2017m1), rn, .))
    gen byte first17_`g' = rn == r17
    drop if t > $MMAX
    gen byte rel = 3
    keep rel focal partner t break_`g' first17_`g'
    tempfile ty`g'
    save `ty`g''
}
use `full', clear
foreach g in K C M {
    merge 1:1 rel focal partner t using `ty`g'', assert(master match) nogen
}
rename (g_K g_C g_M g_U) (pt_K pt_C pt_M pt_U)
gen str80 pt_types = ""
foreach s of local SUBS {
    replace pt_types = pt_types + cond(pt_types == "", "", " ") + "`s'" if d_`s' == 1
}
drop d_*
foreach v in pt_K pt_C pt_M pt_U {
    replace `v' = . if rel != 3
}
replace pt_types = "" if rel != 3
encode pt_types, gen(pt_types_c) label(pt_types)
drop pt_types
rename pt_types_c pt_types

* ==========================================================================================
* 4. 接上两边的企业信息，生成处理组变量和样本标记
* ==========================================================================================
* ---- A 股企业 i ----
rename focal company_id
merge m:1 company_id using "$CLEAN/firm.dta", keep(master match) nogen
rename (country2 size lev roa ato growth) (fcty size_i lev_i roa_i ato_i growth_i)
merge m:1 company_id using "$CLEAN/entity.dta", keep(master match) nogen keepusing(name)
rename (company_id name) (focal name_i)
merge m:1 sic using "$CLEAN/tariff.dta", keep(master match)
gen byte tariff_i = cond(sic == ., ., _merge == 3)           // 所在行业被美国加征关税；SIC 未知为缺失
drop _merge
gen int year = year(dofm(t))
merge m:1 stkcd year using "$CLEAN/st_year.dta", keep(master match) nogen   // ST 数据只有 2016-2019 年

* ---- 境外企业 j ----
preserve
    use company_id stkcd country2 sic size lev roa ato growth using "$CLEAN/firm.dta", clear
    rename (company_id stkcd country2 sic size lev roa ato growth) ///
        (partner stkcd_j pcty sic_j size_j lev_j roa_j ato_j growth_j)
    tempfile fj
    save `fj'
    use company_id name using "$CLEAN/entity.dta", clear
    rename (company_id name) (partner name_j)
    tempfile nj
    save `nj'
restore
merge m:1 partner using `fj', keep(master match) nogen
merge m:1 partner using `nj', keep(master match) nogen
replace roa_i = roa_i / 100                                 // ROA 用小数
replace roa_j = roa_j / 100

* ---- 筛选条件（只标记，不筛选）----
gen byte fA   = stkcd != "" & in_csmar == 1 & inlist(markettype, 1, 4, 16, 32)   // CSMAR 确认的 A 股
gen byte fin  = substr(nnindcd, 1, 1) == "J"                                     // 金融业
gen byte late = listd > td(31dec2017) & listd < .                                // 2018 年及以后上市
gen byte xi   = !missing(size_i, lev_i, roa_i, ato_i, growth_i)
gen byte xj   = !missing(size_j, lev_j, roa_j, ato_j, growth_j)

* ---- 处理组与冲击后 ----
gen byte us         = pcty == "US"
gen byte impact     = tariff_i * us
gen byte post       = cond(tariff_i == 1, t >= fem, t >= tm(2018m7)) if tariff_i < .
gen byte postimpact = post * impact

* ---- 两个文件夹的样本（05_check_samples.do 核对与原文件逐行一致）----
gen byte ok_i  = fA & !fin & !late & st_y != 1 & tariff_i < . & xi                 // A 股企业一方的筛选
gen byte ok_j  = !inlist(pcty, "CN", "", "OFF")                                    // 境外企业：国家已知且不是离岸注册地
gen byte s_jjyj_panel = rel == 1 & ok_i & ok_j & xj & stkcd_j == "" & inrange(t, tm(2017m1), tm(2020m6))
gen byte s_jjyj       = s_jjyj_panel & t <= tm(2019m12) & first17
gen byte s_pt_panel   = rel == 3 & ok_i & ok_j & inrange(t, tm(2017m1), tm(2020m6))
gen byte s_pt         = s_pt_panel & t <= tm(2019m12) & first17
foreach g in K C M {
    gen byte s_pt_`g' = rel == 3 & ok_i & ok_j & pt_`g' == 1 & first17_`g' == 1 & inrange(t, tm(2017m1), tm(2019m12))
}
drop ok_i ok_j

* ==========================================================================================
* 5. 变量说明（label 是中文说明；char [en] 是英文说明，04_export.do 写进变量说明表）
* ==========================================================================================
label var rel        "关系类型：1 供应链 i 供货给 j；2 供应链 j 供货给 i；3 合作关系"
label var pid        "关系编号 = rel x focal x partner（与两个文件夹里的 pid 编号不同）"
label var focal      "A 股企业 i（FactSet company_id，换 ID 后）"
label var partner    "境外企业 j（FactSet company_id，换 ID 后）"
label var t          "年月"
label var year       "年"
label var stkcd      "i 的 A 股代码"
label var name_i     "i 的名称（FactSet）"
label var fcty       "i 的国家"
label var sic        "i 的 4 位 SIC（Worldscope）"
label var nnindcd    "i 的证监会 2012 版行业代码（CSMAR）"
label var name_j     "j 的名称（FactSet）"
label var pcty       "j 的国家（空 = 未知；OFF = 只有离岸注册地）"
label var sic_j      "j 的 4 位 SIC（Worldscope）"
label var stkcd_j    "j 的 A 股代码（几乎都为空）"
label var run        "这对企业这类关系的第几段（2016m1 起数）"
label var run_start  "这一段的第一个月（2016m1 表示 2016m1 或更早就已存在）"
label var run_end    "这一段的最后一个月（2024m7 且 break = 0 表示到数据截止仍存续）"
label var break      "Break：本月存在、下月不存在"
label var break1     "Break1：下个月存在、再下个月不存在"
label var break2     "Break2：晚 2 个月断裂"
label var break3     "Break3：晚 3 个月断裂"
label var first17    "2017m1 起（含 2017m1 仍在持续）的第一段关系"
label var src_i      "本月有以 i 为 source 的 FactSet 记录"
label var src_j      "本月有以 j 为 source 的 FactSet 记录"
label var pt_K       "合作关系：本月有知识类"
label var pt_C       "合作关系：本月有资本类"
label var pt_M       "合作关系：本月有市场类"
label var pt_U       "合作关系：本月有未归类的（子类型 NA）"
label var pt_types   "合作关系：本月有效的 FactSet 子类型"
label var break_K    "知识类：本月存在、下月不存在"
label var break_C    "资本类：本月存在、下月不存在"
label var break_M    "市场类：本月存在、下月不存在"
label var first17_K  "知识类：2017m1 起的第一段"
label var first17_C  "资本类：2017m1 起的第一段"
label var first17_M  "市场类：2017m1 起的第一段"
label var tariff_i   "Tariff：i 的行业被美国加征关税"
label var fem        "i 的行业首次加征关税生效月"
label var us         "US：j 是美国企业"
label var impact     "Impact = Tariff x US"
label var post       "Post（日历时间：冲击月及以后）"
label var postimpact "Post x Impact（论文写法的 Post：只有处理组冲击后为 1）"
label var size_i     "Size_i：ln(总资产/1000 万美元)，2017"
label var lev_i      "Lev_i：债务/总资产，2017"
label var roa_i      "ROA_i（小数），2017"
label var ato_i      "ATO_i：营业收入/总资产，2017"
label var growth_i   "Growth_i：营业收入增长率，2017"
label var xi         "i 的 2017 年 5 项财务指标齐全"
label var size_j     "Size_j，2017"
label var lev_j      "Lev_j，2017"
label var roa_j      "ROA_j，2017"
label var ato_j      "ATO_j，2017"
label var growth_j   "Growth_j，2017"
label var xj         "j 的 2017 年 5 项财务指标齐全"
label var in_csmar   "i 的代码在 CSMAR 公司文件里"
label var markettype "i 的 CSMAR 市场类型"
label var listd      "i 的上市日期（CSMAR）"
label var fA         "CSMAR 确认的 A 股（沪深主板、创业板、科创板）"
label var fin        "金融业（证监会行业 J）"
label var late       "2018 年及以后上市"
label var st_y       "当年有 ST 交易日（只有 2016-2019 年）"
label var s_jjyj_panel "在 replication_jjyj2024 的 panel_monthly.dta 里"
label var s_jjyj       "在 replication_jjyj2024 的 analysis_sample.dta 里"
label var s_pt_panel   "在 partnership_break 的 panel_monthly.dta 里"
label var s_pt         "在 partnership_break 的 analysis_sample.dta 里"
label var s_pt_K       "在 partnership_break 的 analysis_K.dta 里"
label var s_pt_C       "在 partnership_break 的 analysis_C.dta 里"
label var s_pt_M       "在 partnership_break 的 analysis_M.dta 里"

char rel[en]        "Relationship type: 1 supply_out = i is the supplier and j the customer (the direction studied in the paper); 2 supply_in = j is the supplier and i the customer; 3 partnership (undirected). The CSV/parquet files store the text."
char pid[en]        "Relationship id = group(rel, focal, partner). Not the same numbering as pid in the analysis files of the two other folders."
char focal[en]      "Firm i: A-share listed firm (FactSet company_id after replacing discontinued IDs by their successors)."
char partner[en]    "Firm j: counterparty outside mainland China, incl. Hong Kong, Macao and Taiwan (FactSet company_id after ID replacement)."
char t[en]          "Year-month. One row per month in which the relationship exists (any day in the month)."
char year[en]       "Calendar year of t."
char stkcd[en]      "Firm i: 6-digit A-share stock code (from FactSet tickers 60/68xxxx-SHG or 00/30xxxx-SHE)."
char name_i[en]     "Firm i: company name in FactSet."
char fcty[en]       "Firm i: country (FactSet address country, else home region; KY, VG, BM and XZ are coded OFF)."
char sic[en]        "Firm i: 4-digit SIC from Worldscope (2017, else the nearest year)."
char nnindcd[en]    "Firm i: CSRC 2012 industry code from CSMAR (J = finance)."
char name_j[en]     "Firm j: company name in FactSet."
char pcty[en]       "Firm j: country, same coding as fcty. Empty = unknown; OFF = only an offshore registration (KY, VG, BM, XZ)."
char sic_j[en]      "Firm j: 4-digit SIC from Worldscope."
char stkcd_j[en]    "Firm j: A-share code if FactSet has one (almost always empty)."
char run[en]        "Spell number of this relationship (rel, i, j): a spell is a run of consecutive months; counted from 2016m1."
char run_start[en]  "First month of this spell. 2016m1 means the spell already existed in or before 2016m1."
char run_end[en]    "Last month of this spell within 2016m1-2024m7. run_end = 2024m7 with break = 0 means still active when the data end."
char break[en]      "Break = 1 if the relationship exists this month and not next month."
char break1[en]     "Break1 = 1 if the relationship exists next month and breaks then (one month later). Missing where the data end too early to tell."
char break2[en]     "Break2: breaks two months later. Missing where the data end too early to tell."
char break3[en]     "Break3: breaks three months later. Missing where the data end too early to tell."
char first17[en]    "1 = this spell is the first spell of (rel, i, j) seen from 2017m1 on (a spell already running in 2017m1 counts). The regression samples keep first17 = 1."
char src_i[en]      "1 = in this month at least one FactSet record of this relationship has i as the source company."
char src_j[en]      "1 = in this month at least one FactSet record of this relationship has j as the source company."
char pt_K[en]       "Partnerships only: a knowledge-type partnership is active this month (subtypes RESCOLB, TECHNGY, LICENIN, LICENOT, PLICENS, INTPROD). Missing for supply-chain rows."
char pt_C[en]       "Partnerships only: a capital-type partnership is active this month (INVESTO, EINVEST, JVENTUR)."
char pt_M[en]       "Partnerships only: a market-type partnership is active this month (DISTRIB, MARKTNG, MANUFAC)."
char pt_U[en]       "Partnerships only: an unclassified partnership (FactSet subtype NA) is active this month."
char pt_types[en]   "Partnerships only: FactSet PARTNER subtypes active this month, space-separated (labelled integer in Stata, text in CSV/parquet)."
char break_K[en]    "Rows with pt_K = 1: the knowledge-type partnership exists this month and not next month (even if other types continue)."
char break_C[en]    "Rows with pt_C = 1: the capital-type partnership exists this month and not next month."
char break_M[en]    "Rows with pt_M = 1: the market-type partnership exists this month and not next month."
char first17_K[en]  "Rows with pt_K = 1: first knowledge-type spell of the pair seen from 2017m1 on."
char first17_C[en]  "Rows with pt_C = 1: first capital-type spell of the pair seen from 2017m1 on."
char first17_M[en]  "Rows with pt_M = 1: first market-type spell of the pair seen from 2017m1 on."
char tariff_i[en]   "1 = firm i's SIC is on the US tariff lists against China (sic_code.csv, the same list as the paper's appendix table 1). Missing if i's SIC is unknown."
char fem[en]        "First month in which a US tariff on firm i's SIC took effect."
char us[en]         "1 = firm j is a US firm (pcty = US)."
char impact[en]     "Impact = tariff_i x us (treated pair)."
char post[en]       "Calendar post-shock dummy: t >= fem for tariffed industries, t >= 2018m7 otherwise. Missing if tariff_i is missing."
char postimpact[en] "Post as defined in the paper = post x impact: 1 only for treated pairs from the shock month on. Named Post in replication_jjyj2024 (post is named post_e there)."
char size_i[en]     "Firm i, 2017: ln(total assets in USD / 10 million) (Worldscope item 7230)."
char lev_i[en]      "Firm i, 2017: (short-term debt 3051 + long-term debt 3251) / total assets 2999. Winsorized 1/99 on the 2017 cross-section of all Worldscope firms."
char roa_i[en]      "Firm i, 2017: return on assets as a fraction (Worldscope 8326 / 100). Winsorized 1/99 on the 2017 cross-section of all Worldscope firms."
char ato_i[en]      "Firm i, 2017: sales 1001 / total assets 2999. Winsorized 1/99 on the 2017 cross-section of all Worldscope firms."
char growth_i[en]   "Firm i, 2017: sales 2017 / sales 2016 - 1. Winsorized 1/99 on the 2017 cross-section of all Worldscope firms."
char xi[en]         "1 = firm i has all five 2017 financial variables."
char size_j[en]     "Firm j, 2017: same definition as size_i."
char lev_j[en]      "Firm j, 2017: same definition as lev_i."
char roa_j[en]      "Firm j, 2017: same definition as roa_i."
char ato_j[en]      "Firm j, 2017: same definition as ato_i."
char growth_j[en]   "Firm j, 2017: same definition as growth_i."
char xj[en]         "1 = firm j has all five 2017 financial variables."
char in_csmar[en]   "1 = firm i's stock code is in the CSMAR company file (TRD_Co)."
char markettype[en] "Firm i: CSMAR market type. 1 Shanghai A (excl. STAR), 2 Shanghai B, 4 Shenzhen A (excl. ChiNext), 8 Shenzhen B, 16 ChiNext, 32 STAR, 64 Beijing A."
char listd[en]      "Firm i: listing date (CSMAR)."
char fA[en]         "1 = A-share confirmed by CSMAR: in_csmar = 1 and markettype in 1, 4, 16, 32."
char fin[en]        "1 = financial industry (CSRC code starting with J)."
char late[en]       "1 = listed in 2018 or later."
char st_y[en]       "1 = firm i had ST trading days in this calendar year (CSMAR Trdsta). Available for 2016-2019 only; missing otherwise."
char s_jjyj_panel[en] "1 = row is in replication_jjyj2024/data/clean/panel_monthly.dta (supply chain, 2017m1-2020m6, all sample filters)."
char s_jjyj[en]       "1 = row is in replication_jjyj2024/data/clean/analysis_sample.dta (supply-chain regression sample)."
char s_pt_panel[en]   "1 = row is in partnership_break/data/clean/panel_monthly.dta (partnerships, 2017m1-2020m6, all sample filters)."
char s_pt[en]         "1 = row is in partnership_break/data/clean/analysis_sample.dta (partnership regression sample)."
char s_pt_K[en]       "1 = row is in partnership_break/data/clean/analysis_K.dta (knowledge-type regression sample; use break_K as the outcome)."
char s_pt_C[en]       "1 = row is in partnership_break/data/clean/analysis_C.dta (capital-type regression sample; use break_C)."
char s_pt_M[en]       "1 = row is in partnership_break/data/clean/analysis_M.dta (market-type regression sample; use break_M)."

order rel pid focal partner t year stkcd name_i fcty sic nnindcd name_j pcty sic_j stkcd_j ///
    run run_start run_end break break1 break2 break3 first17 src_i src_j ///
    pt_K pt_C pt_M pt_U pt_types break_K break_C break_M first17_K first17_C first17_M ///
    tariff_i fem us impact post postimpact ///
    size_i lev_i roa_i ato_i growth_i xi size_j lev_j roa_j ato_j growth_j xj ///
    in_csmar markettype listd fA fin late st_y ///
    s_jjyj_panel s_jjyj s_pt_panel s_pt s_pt_K s_pt_C s_pt_M
sort pid t
label data "完整面板：A 股企业 x 境外企业 x 关系类型 x 月，2016m1-2024m7"
compress
recast strL name_i name_j                                   // 名称重复很多，strL 存得小（文件从 370MB 降到约 210MB）
save "$CLEAN/full_panel.dta", replace
di as txt "完整面板：行数 = " _N

* ==========================================================================================
* 6. 规模：每类关系、每类关系 x 年
* ==========================================================================================
* rel = 0 一行是三类合计（关系对按 rel x i x j 算，同一对企业既有供应链又有合作关系时算两对）
preserve
    egen byte tp  = tag(pid)
    egen byte tf  = tag(rel focal)
    egen byte tj  = tag(rel partner)
    egen byte tfa = tag(focal)
    egen byte tja = tag(partner)
    gen  byte tpu = tp & us
    gen  byte tpt = tp & impact == 1
    gen  long one = 1
    tempfile base6
    save `base6'
    collapse (sum) rows = one pairs = tp pairs_us = tpu pairs_treated = tpt firms_i = tfa firms_j = tja ///
        breaks = break (min) first_month = t (max) last_month = t
    gen byte rel = 0
    tempfile tot
    save `tot'
    use `base6', clear
    collapse (sum) rows = one pairs = tp pairs_us = tpu pairs_treated = tpt firms_i = tf firms_j = tj ///
        breaks = break (min) first_month = t (max) last_month = t, by(rel)
    append using `tot'
    label define rel 0 "all", modify
    label values rel rel
    sort rel
    format rows pairs pairs_us pairs_treated firms_i firms_j breaks %12.0f
    format first_month last_month %tmCCYY-NN
    order rel
    list, noobs abbreviate(14)
    export delimited using "$OUT/tables/full_panel_summary.csv", replace
restore
preserve
    egen byte tpy = tag(pid year)
    gen  long one = 1
    collapse (sum) rows = one pairs = tpy breaks = break (mean) break_rate = break, by(rel year)
    format rows pairs breaks %12.0f
    format break_rate %6.4f
    list, noobs sepby(rel)
    export delimited using "$OUT/tables/full_panel_by_year.csv", replace
restore

* ---- 两个文件夹的样本规模（应与它们的 README 一致）----
foreach s in s_jjyj_panel s_jjyj s_pt_panel s_pt s_pt_K s_pt_C s_pt_M {
    quietly count if `s'
    di as txt "`s'：行数 = " r(N)
}

log close l03
