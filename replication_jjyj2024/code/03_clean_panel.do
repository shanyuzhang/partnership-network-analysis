* ==========================================================================================
* 03_clean_panel.do —— 第三步清洗：供应链关系记录 -> 关系对 x 月面板 -> 回归样本
*
* 输入：$RAW_FACTSET/$F_REL   FactSet Revere 关系记录
*       $CLEAN/successor.dta、firm.dta、tariff.dta、st_year.dta（01、02 生成）
* 输出：$CLEAN/panel_monthly.dta    2017m1-2020m6 的关系对 x 月面板（已做全部样本筛选；图 1 用）
*       $CLEAN/analysis_sample.dta  回归样本：2017m1-2019m12、每对只看第一段，控制变量已按样本缩尾（表 2、附表 3、附图 1 用）
*
* 口径（与论文一致或最接近）：
*   观测单位   中国供应商 i x 外国客户 j x 月
*   关系       FactSet 的 CUSTOMER / SUPPLIER 记录，供应商和客户由哪一方报告都算；同一记录 ID 的前后版本
*              相隔 7 天以内视为同一段关系
*   存在       某月里任意一天关系有效，这个月就算存在
*   断裂       Break = 本月存在、下个月不存在；Break1/2/3 = 再晚 1/2/3 个月断裂
*   样本       2017m1-2019m12；每对企业只看 2017 年起的第一段关系；断裂之后这一对退出
*   供应商 i   CSMAR 确认的 A 股（沪深主板、创业板、科创板）、非金融、2017 年底前上市、当年没有被 ST
*              （只剔除被 ST 的那一年）、能对上 SIC、2017 年 5 项财务指标齐全
*   客户 j     非中国内地企业（港澳台算外国；国家未知或只有离岸注册地的剔除）、2017 年 5 项财务指标齐全
*   Impact     供应商所在 SIC 行业被美国加征关税 x 客户是美国企业
*   Post       论文写法：只有受冲击的关系对（Impact = 1）在本行业首次加征关税生效月及以后为 1
*   控制变量   Post x 两边 2017 年的 Size、Lev、ROA、ATO、Growth（在回归样本上按观测 1%/99% 缩尾）
* ==========================================================================================
clear all
do "code/00_config.do"
capture log close l03
log using "$OUT/logs/03_clean_panel.log", replace text name(l03)

* ==========================================================================================
* 1. 关系记录 -> 关系段（同一记录 ID 前后版本相隔 <= 7 天视为同一段）
* ==========================================================================================
import delimited using "$RAW_FACTSET/$F_REL", varnames(1) colrange(1:6) stringcols(_all) clear
keep if inlist(rel_type, "CUSTOMER", "SUPPLIER")
destring source_company_id target_company_id, replace force
gen ds = date(start_, "YMD")
gen de = date(end_,   "YMD")
replace de = . if de > td(31dec2099)              // 远期日期表示至今有效
format ds de %td
drop if ds == . | source_company_id == . | target_company_id == .
drop if source_company_id == target_company_id
gen byte cur = de == .                            // 至今有效
keep id rel_type source_company_id target_company_id ds de cur
sort id ds de, stable
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
di as txt "供应链关系段 = " _N

* ==========================================================================================
* 2. 换 ID，确定供应商和客户，只留“中国供应商 -> 外国客户”
*    CUSTOMER 记录：source 是供应商、target 是客户；SUPPLIER 记录相反
*    中国供应商候选 = 有 A 股代码，或总部在中国内地且有 SIC（最终只留 A 股，见第 4 步）
* ==========================================================================================
foreach s in src tgt {
    rename `s' company_id
    quietly merge m:1 company_id using "$CLEAN/successor.dta", keep(master match)
    quietly replace company_id = company_id_new if _merge == 3
    drop company_id_new _merge
    rename company_id `s'
}
drop if src == tgt
gen long supplier = cond(rel_type == "CUSTOMER", src, tgt)
gen long customer = cond(rel_type == "CUSTOMER", tgt, src)
foreach s in supplier customer {
    rename `s' company_id
    quietly merge m:1 company_id using "$CLEAN/firm.dta", keep(master match) nogen keepusing(stkcd country2 sic)
    gen byte cand_`s' = stkcd != "" | (country2 == "CN" & sic < .)
    gen byte cn_`s'   = stkcd != "" | country2 == "CN"
    drop stkcd country2 sic
    rename company_id `s'
}
keep if cand_supplier & !cn_customer
gen long focal   = supplier
gen long partner = customer

* ==========================================================================================
* 3. 关系段 -> 关系对 x 月（月内任一天有效即存在），断裂与第一段
* ==========================================================================================
gen int ms = mofd(ds)
gen int me = cond(cur, $MEXT, mofd(de))
keep if me >= ms & me >= $M0 & ms <= $MMAX
replace ms = max(ms, $M0)
gen int mb = min(me, $MMAX + 1)
gen int nm = mb - ms + 1
gen long sid = _n
expand nm
bys sid: gen int t = ms + _n - 1
gen byte one = 1
collapse (max) one, by(focal partner t)
drop one
format t %tm

egen long pid = group(focal partner)
sort pid t
by pid: gen byte runstart = _n == 1 | t != t[_n-1] + 1
by pid: gen int  runid    = sum(runstart)
by pid: gen byte break    = _n == _N | t[_n+1] != t + 1      // 本月存在、下个月不存在
replace break = 0 if t >= $MMAX + 1                         // 数据最后一个月之后无法判断
by pid: gen byte break1 = t[_n+1] == t + 1 & break[_n+1]  == 1
by pid: gen byte break2 = t[_n+1] == t + 1 & break1[_n+1] == 1
by pid: gen byte break3 = t[_n+1] == t + 1 & break2[_n+1] == 1
keep if inrange(t, tm(2017m1), tm(2020m6))                  // 图 1 要用到 2020 年上半年
bys pid: egen int r17 = min(runid)
gen byte first17 = runid == r17                             // 2017 年起的第一段关系
drop r17 runstart
gen int year = year(dofm(t))

* ==========================================================================================
* 4. 接上企业信息，做样本筛选，生成 Impact 和 Post
* ==========================================================================================
rename focal company_id
quietly merge m:1 company_id using "$CLEAN/firm.dta", keep(master match) nogen
rename (country2 size lev roa ato growth) (fcty size_i lev_i roa_i ato_i growth_i)
rename company_id focal
quietly merge m:1 sic using "$CLEAN/tariff.dta", keep(master match)
gen byte tariff_i = cond(sic == ., ., _merge == 3)           // 供应商所在行业被美国加征关税
drop _merge
quietly merge m:1 stkcd year using "$CLEAN/st_year.dta", keep(master match) nogen
replace st_y = 0 if st_y == .
rename partner company_id
quietly merge m:1 company_id using "$CLEAN/firm.dta", keep(master match) nogen keepusing(country2 size lev roa ato growth)
rename (country2 size lev roa ato growth) (pcty size_j lev_j roa_j ato_j growth_j)
rename company_id partner
replace roa_i = roa_i / 100                                 // ROA 用小数
replace roa_j = roa_j / 100

gen byte fA   = stkcd != "" & in_csmar == 1 & inlist(markettype, 1, 4, 16, 32)   // CSMAR 确认的 A 股
gen byte fin  = substr(nnindcd, 1, 1) == "J"                                     // 金融业
gen byte late = listd > td(31dec2017) & listd < .                                // 2018 年及以后上市
gen byte stY  = st_y == 1                                                        // 当年被 ST
gen byte xi   = !missing(size_i, lev_i, roa_i, ato_i, growth_i)
gen byte xj   = !missing(size_j, lev_j, roa_j, ato_j, growth_j)
keep if fA & !fin & !late & !stY & tariff_i < . & xi & xj & !inlist(pcty, "CN", "", "OFF")

gen byte us     = pcty == "US"                                                   // 客户是美国企业
gen byte impact = tariff_i * us
gen byte post_e = cond(tariff_i == 1, t >= fem, t >= tm(2018m7))                 // 日历时间上的冲击后
gen byte Post   = post_e * impact                                                // 论文写法：只有处理组冲击后为 1

label var focal    "中国供应商（FactSet company_id，换 ID 后）"
label var partner  "外国客户（FactSet company_id，换 ID 后）"
label var pid      "关系对"
label var t        "年月"
label var break    "Break：本月存在、下月不存在"
label var break1   "Break1：下个月存在、再下个月不存在"
label var break2   "Break2：晚 2 个月断裂"
label var break3   "Break3：晚 3 个月断裂"
label var first17  "2017 年起的第一段关系"
label var tariff_i "供应商行业被美国加征关税"
label var fem      "供应商行业首次加征关税生效月"
label var us       "客户是美国企业"
label var impact   "Impact = 加征关税行业 x 美国客户"
label var Post     "Post（论文写法：处理组冲击后为 1）"
label var size_i   "Size_i：ln(总资产/1000 万美元)，2017"
label var lev_i    "Lev_i：债务/总资产，2017"
label var roa_i    "ROA_i（小数），2017"
label var ato_i    "ATO_i：营业收入/总资产，2017"
label var growth_i "Growth_i：营业收入增长率，2017"
label var size_j   "Size_j，2017"
label var lev_j    "Lev_j，2017"
label var roa_j    "ROA_j，2017"
label var ato_j    "ATO_j，2017"
label var growth_j "Growth_j，2017"
keep focal partner pid t year break break1 break2 break3 first17 stkcd sic nnindcd fcty pcty ///
    tariff_i fem us impact post_e Post size_i lev_i roa_i ato_i growth_i size_j lev_j roa_j ato_j growth_j
order focal partner pid t year break break1 break2 break3 first17
sort pid t
compress
save "$CLEAN/panel_monthly.dta", replace
di as txt "2017m1-2020m6 面板：关系对 x 月 = " _N

* ==========================================================================================
* 5. 回归样本：2017m1-2019m12、每对第一段；控制变量在样本上按观测 1%/99% 缩尾（w_ 开头）
* ==========================================================================================
keep if t <= tm(2019m12) & first17
foreach v in size lev roa ato growth {
    foreach k in i j {
        quietly _pctile `v'_`k', p(1 99)
        gen double w_`v'_`k' = min(max(`v'_`k', r(r1)), r(r2)) if `v'_`k' < .
        label var w_`v'_`k' "`v'_`k'（回归样本上 1%/99% 缩尾）"
    }
}
compress
save "$CLEAN/analysis_sample.dta", replace

egen byte tf = tag(focal)
egen byte tc = tag(partner)
egen byte tp = tag(pid)
di as txt _n "===== 回归样本（论文表 1：中国企业 1,001；外国企业 1,546；关系对 4,989；关系对 x 月 83,946）====="
count if tf
di as txt "中国供应商 = " r(N)
count if tc
di as txt "外国客户 = " r(N)
count if tp
di as txt "关系对 = " r(N)
count
di as txt "关系对 x 月 = " r(N)
summarize break
di as txt "Break 均值（论文 0.0261）= " %6.4f r(mean)
summarize impact if tp
di as txt "Impact 均值（关系对层面，论文 0.176）= " %6.4f r(mean)

log close l03
