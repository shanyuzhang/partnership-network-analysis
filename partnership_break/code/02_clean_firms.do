* ==========================================================================================
* 02_clean_firms.do —— 第二步清洗：企业层面的数据
*
* 输入：$RAW_OTHER/$F_TARIFF   美国加征关税的 SIC 行业及生效日期
*       $RAW_OTHER/$F_TRD      CSMAR 日个股回报率文件 2016-2019（4 个文件，用交易状态判断 ST）
*       $RAW_OTHER/$F_CO       CSMAR 公司文件
*       $RAW_OTHER/$F_WS       Worldscope 年度财务数据
*       $CLEAN/entity.dta      （01 生成）
* 输出：$CLEAN/tariff.dta      每个 SIC 一行：本行业首次被加征关税生效的月份 fem
*       $CLEAN/st_year.dta     每家 A 股企业 x 年：当年是否有 ST 交易日
*       $CLEAN/firm.dta        每家 FactSet 公司一行：A 股代码、国家、SIC、2017 年 5 项财务指标、CSMAR 信息
*
* 2017 年财务指标（论文表 1 / 附表 2 的口径，Worldscope 字段号）：
*   Size   = ln(总资产美元 7230 / 1000 万)
*   Lev    = (短期债务 3051 + 长期债务 3251) / 总资产 2999       （债务 / 总资产，和论文表 1 的分布最接近）
*   ROA    = 8326（百分数；03 里换成小数）
*   ATO    = 营业收入 1001 / 总资产 2999
*   Growth = 2017 年营业收入 / 2016 年营业收入 - 1
*   Lev、ROA、ATO、Growth 先在 Worldscope 全部公司的 2017 年截面上 1%/99% 缩尾；
*   回归用的控制变量在 03 里再按回归样本缩尾一次。
* ==========================================================================================
clear all
do "code/00_config.do"
capture log close l02
log using "$OUT/logs/02_clean_firms.log", replace text name(l02)

* ==========================================================================================
* 1. 加征关税行业：每个 SIC 首次生效的月份
* ==========================================================================================
import delimited using "$RAW_OTHER/$F_TARIFF", varnames(1) clear
gen int fem = mofd(date(effective_date, "YMD"))
collapse (min) fem, by(sic_code)
rename sic_code sic
format fem %tm
di as txt "加征关税的 SIC 行业数 = " _N "，按首次生效月份："
tab fem
compress
save "$CLEAN/tariff.dta", replace

* ==========================================================================================
* 2. ST：每家 A 股企业每年是否有 ST 交易日
*    交易状态 Trdsta：1 正常、4 S、7 G、10 U、13 N 不是 ST；其余（ST、*ST、SST、S*ST、GST、G*ST、UST、U*ST、
*    NST、N*ST、PT）是 ST。回归样本只剔除企业被 ST 的那一年。
* ==========================================================================================
clear
tempfile sty
save `sty', emptyok
foreach f of global F_TRD {
    import delimited using "$RAW_OTHER/`f'.csv", varnames(1) stringcols(_all) encoding(utf-8) clear
    destring trdsta, replace
    gen int year = real(substr(trddt, 1, 4))
    gen byte st_y = !inlist(trdsta, 1, 4, 7, 10, 13)
    collapse (max) st_y, by(stkcd year)
    append using `sty'
    save `sty', replace
}
use `sty', clear
collapse (max) st_y, by(stkcd year)
tab year st_y
compress
save "$CLEAN/st_year.dta", replace

* ==========================================================================================
* 3. CSMAR 公司文件：市场类型、上市日期、证监会行业
* ==========================================================================================
import delimited using "$RAW_OTHER/$F_CO", varnames(1) stringcols(_all) encoding(utf-8) clear
keep stkcd listdt nnindcd markettype
gen listd = date(listdt, "YMD")
format listd %td
destring markettype, replace
drop listdt
tempfile csmar
save `csmar'

* ==========================================================================================
* 4. Worldscope：SIC 和 2017 年财务指标
* ==========================================================================================
import delimited using "$RAW_OTHER/$F_WS", varnames(1) stringcols(_all) clear
destring code year_ item1001 item2999 item3051 item3251 item7230 item8326 item7021, replace force
replace item6008 = upper(strtrim(item6008))          // ISIN
replace item6004 = upper(strtrim(item6004))          // CUSIP
tempfile ws wsic wcode wctl wisin wcus
save `ws'

* SIC：优先用 2017 年，没有就用离 2017 年最近的一年（同样近时用更早的一年）
keep if item7021 < .
gen pri = abs(year_ - 2017) + (year_ > 2017) * 0.5
sort code pri, stable
by code: keep if _n == 1
keep code item7021
rename item7021 sic
save `wsic'
use `ws', clear
gen ny = 1
collapse (sum) ny, by(code)
merge 1:1 code using `wsic', nogen
gen byte has_sic = sic < .
save `wcode'

* 2017 年财务指标
use `ws', clear
keep if inlist(year_, 2016, 2017)
bys code: egen double s16 = max(cond(year_ == 2016, item1001, .))
keep if year_ == 2017
gen double size   = ln(item7230 / 1e7)
gen double lev    = (item3051 + item3251) / item2999
gen double roa    = item8326
gen double ato    = item1001 / item2999
gen double growth = item1001 / s16 - 1 if s16 > 0
foreach v in lev roa ato growth {
    _pctile `v', p(1 99)
    replace `v' = r(r1) if `v' < r(r1)
    replace `v' = r(r2) if `v' > r(r2) & `v' < .
}
keep code size lev roa ato growth
save `wctl'

* ISIN -> Worldscope code；CUSIP8 -> code（一个代码对应多个 code 时：先要有 SIC，再要年份多，再取 code 小的）
use `ws', clear
keep if strlen(item6008) == 12
contract code item6008
drop _freq
merge m:1 code using `wcode', keep(match) nogen
gsort item6008 -has_sic -ny code
by item6008: keep if _n == 1
rename item6008 isin
keep isin code
save `wisin'
use `ws', clear
gen cusip8 = substr(item6004, 1, 8)
keep if strlen(cusip8) == 8
contract code cusip8
drop _freq
merge m:1 code using `wcode', keep(match) nogen
gsort cusip8 -has_sic -ny code
by cusip8: keep if _n == 1
keep cusip8 code
rename code code_c
save `wcus'

* ==========================================================================================
* 5. 每家 FactSet 公司一行：先用 ISIN、再用 CUSIP8 对到 Worldscope；A 股企业再接上 CSMAR
* ==========================================================================================
use "$CLEAN/entity.dta", clear
keep company_id stkcd country2 isin cusip8
merge m:1 isin   using `wisin', keep(master match) nogen
merge m:1 cusip8 using `wcus',  keep(master match) nogen
replace code = code_c if code == .
drop code_c
merge m:1 code using `wcode', keep(master match) nogen keepusing(sic)
merge m:1 code using `wctl',  keep(master match) nogen
merge m:1 stkcd using `csmar', keep(master match)
gen byte in_csmar = _merge == 3 & stkcd != ""
drop _merge
replace markettype = . if stkcd == ""
replace nnindcd    = "" if stkcd == ""
replace listd      = . if stkcd == ""
keep company_id stkcd country2 sic size lev roa ato growth in_csmar markettype listd nnindcd
sort company_id
compress
save "$CLEAN/firm.dta", replace
di as txt "公司数 = " _N
count if sic < .
di as txt "其中对上 Worldscope SIC 的 = " r(N)
count if in_csmar
di as txt "其中是 CSMAR 里的 A 股企业 = " r(N)

log close l02
