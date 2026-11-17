* ==========================================================================================
* 03_clean_panel.do —— 第三步清洗：合作关系记录 -> 关系对 x 月面板 -> 回归样本
*
* 输入：$RAW_FACTSET/$F_REL   FactSet Revere 关系记录
*       $CLEAN/successor.dta、firm.dta、tariff.dta、st_year.dta（01、02 生成）
* 输出：$CLEAN/panel_monthly.dta    全部合作关系，2017m1-2020m6 的关系对 x 月面板（已做全部样本筛选；图 1 用）
*       $CLEAN/analysis_sample.dta  全部合作关系的回归样本：2017m1-2019m12、每对只看第一段，
*                                   回归用的变量都已生成（04、06、07 用）
*       $CLEAN/analysis_K.dta、analysis_C.dta、analysis_M.dta   三大类各自的回归样本（06、07 用）
*
* 口径（清洗与 replication_jjyj2024 的供应链复现相同，只是关系换成 FactSet 的合作关系 PARTNER）：
*   观测单位   A 股企业 i x 外国合作伙伴 j x 月
*   关系       FactSet 的 PARTNER 记录，不分方向，哪一方报告都算，A 股企业那一方是 i；
*              同一记录 ID 的前后版本相隔 7 天以内视为同一段关系
*   三大类     按 FactSet 子类型的字面意思分（未注明子类型的 NA 不归类，只进“全部合作关系”）：
*                K 知识类：RESCOLB 研发合作、TECHNGY 技术、LICENIN 许可引进、LICENOT 许可输出、
*                          PLICENS 专利许可、INTPROD 产品集成
*                C 资本类：INVESTO 投资方、EINVEST 被投资方、JVENTUR 合资
*                M 市场类：DISTRIB 分销、MARKTNG 营销、MANUFAC 制造
*              每一类单独建面板：某月“存在” = 这一类至少有一段关系当月有效；
*              断裂 = 这一类本月存在、下个月不存在（同一对企业别的类型的关系还在，也算这一类断裂）
*   存在       某月里任意一天关系有效，这个月就算存在
*   断裂       Break = 本月存在、下个月不存在；Break1/2/3 = 再晚 1/2/3 个月断裂
*   样本       2017m1-2019m12；每对企业只看 2017 年起的第一段关系；断裂之后这一对退出
*   A 股企业 i CSMAR 确认的 A 股（沪深主板、创业板、科创板）、非金融、2017 年底前上市、当年没有被 ST
*              （只剔除被 ST 的那一年）、能对上 SIC、2017 年 5 项财务指标齐全
*   伙伴 j     非中国内地企业（港澳台算外国；国家未知或只有离岸注册地的剔除），不要求有财务数据
*
* 回归用的变量（与 merge_check/core_01 的命名相同）：
*   tariff_i    A 股企业所在 SIC 行业被美国加征关税
*   us          伙伴是美国企业
*   impact      tariff_i x us（处理组）
*   post        日历时间上的冲击后：加征行业为本行业首次加征关税生效月及以后，其余为 2018m7 及以后
*   postimpact  post x impact，即论文写法的 Post：只有处理组在冲击后为 1
*   us_post、us_tariff   us x post、us x tariff_i（三重差分用）
*   postsize postlev postroa postato postgrowth   postimpact x A 股企业 2017 年的 Size、Lev、ROA、ATO、Growth
*               （先在回归样本上按观测 1%/99% 缩尾，缩尾后的值是 w_*_i）
*   firm_m      A 股企业 x 月（固定效应用）
* ==========================================================================================
clear all
do "code/00_config.do"
capture log close l03
log using "$OUT/logs/03_clean_panel.log", replace text name(l03)

* ==========================================================================================
* 1. 合作关系记录 -> 关系段（同一记录 ID 前后版本相隔 <= 7 天视为同一段），标上三大类
* ==========================================================================================
import delimited using "$RAW_FACTSET/$F_REL", varnames(1) colrange(1:6) stringcols(_all) clear
keep if substr(rel_type, 1, 8) == "PARTNER-"
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
gen str7 sub = substr(rel_type, 9, .)
gen str1 grp = cond(inlist(sub, "RESCOLB", "TECHNGY", "LICENIN", "LICENOT", "PLICENS", "INTPROD"), "K", ///
               cond(inlist(sub, "INVESTO", "EINVEST", "JVENTUR"), "C", ///
               cond(inlist(sub, "DISTRIB", "MARKTNG", "MANUFAC"), "M", "-")))
di as txt "合作关系段 = " _N "；子类型 x 大类（- = 未归类）："
tab sub grp, missing

* ==========================================================================================
* 2. 换 ID，确定 A 股企业 i（有 A 股代码的一方）和伙伴 j
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
    quietly merge m:1 company_id using "$CLEAN/firm.dta", keep(master match) nogen keepusing(stkcd)
    rename (company_id stkcd) (`s' stk_`s')
}
keep if stk_src != "" | stk_tgt != ""
gen long focal   = cond(stk_src != "", src, tgt)
gen long partner = cond(stk_src != "", tgt, src)
gen int ms = mofd(ds)
gen int me = cond(cur, $MEXT, mofd(de))
keep if me >= ms & me >= $M0 & ms <= $MMAX
replace ms = max(ms, $M0)
gen int mb = min(me, $MMAX + 1)
gen int nm = mb - ms + 1
keep focal partner grp ms nm
compress
tempfile sp
save `sp'
di as txt "有 A 股代码一方的合作关系段 = " _N
tab grp

* ==========================================================================================
* 3-5. 全部合作关系（ALL）和三大类（K、C、M）各建一个面板
*   3. 关系段 -> 关系对 x 月（月内任一天有效即存在），断裂与第一段
*   4. 接上企业信息，做样本筛选，生成处理组、post、postimpact 和三重差分的交互项
*   5. 回归样本：2017m1-2019m12、每对第一段；控制变量在样本上按观测 1%/99% 缩尾后乘 postimpact
* ==========================================================================================
foreach g in ALL K C M {
    di as txt _n "==================== `g' ===================="
    use `sp', clear
    if "`g'" != "ALL" keep if grp == "`g'"
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
    drop r17 runstart runid
    gen int year = year(dofm(t))

    rename focal company_id
    quietly merge m:1 company_id using "$CLEAN/firm.dta", keep(master match) nogen
    rename (country2 size lev roa ato growth) (fcty size_i lev_i roa_i ato_i growth_i)
    rename company_id focal
    quietly merge m:1 sic using "$CLEAN/tariff.dta", keep(master match)
    gen byte tariff_i = cond(sic == ., ., _merge == 3)           // A 股企业所在行业被美国加征关税
    drop _merge
    quietly merge m:1 stkcd year using "$CLEAN/st_year.dta", keep(master match) nogen
    replace st_y = 0 if st_y == .
    rename partner company_id
    quietly merge m:1 company_id using "$CLEAN/firm.dta", keep(master match) nogen keepusing(country2)
    rename (company_id country2) (partner pcty)
    replace roa_i = roa_i / 100                                 // ROA 用小数

    gen byte fA   = stkcd != "" & in_csmar == 1 & inlist(markettype, 1, 4, 16, 32)   // CSMAR 确认的 A 股
    gen byte fin  = substr(nnindcd, 1, 1) == "J"                                     // 金融业
    gen byte late = listd > td(31dec2017) & listd < .                                // 2018 年及以后上市
    gen byte stY  = st_y == 1                                                        // 当年被 ST
    gen byte xi   = !missing(size_i, lev_i, roa_i, ato_i, growth_i)
    keep if fA & !fin & !late & !stY & tariff_i < . & xi & !inlist(pcty, "CN", "", "OFF")

    gen byte us         = pcty == "US"                                               // 伙伴是美国企业
    gen byte impact     = tariff_i * us                                              // 处理组
    gen byte post       = cond(tariff_i == 1, t >= fem, t >= tm(2018m7))             // 日历时间上的冲击后
    gen byte postimpact = post * impact                                              // 论文写法的 Post
    gen byte us_post    = us * post
    gen byte us_tariff  = us * tariff_i

    label var focal      "A 股企业 i（FactSet company_id，换 ID 后）"
    label var partner    "外国合作伙伴 j（FactSet company_id，换 ID 后）"
    label var pid        "关系对"
    label var t          "年月"
    label var break      "Break：本月存在、下月不存在"
    label var break1     "Break1：下个月存在、再下个月不存在"
    label var break2     "Break2：晚 2 个月断裂"
    label var break3     "Break3：晚 3 个月断裂"
    label var first17    "2017 年起的第一段关系"
    label var tariff_i   "Tariff：A 股企业行业被美国加征关税"
    label var fem        "A 股企业行业首次加征关税生效月"
    label var us         "US partner：伙伴是美国企业"
    label var impact     "Impact = Tariff x US"
    label var post       "Post（日历时间：冲击月及以后）"
    label var postimpact "Post x Impact（论文写法：只有处理组冲击后为 1）"
    label var us_post    "US x Post"
    label var us_tariff  "US x Tariff"
    label var size_i     "Size：ln(总资产/1000 万美元)，2017"
    label var lev_i      "Lev：债务/总资产，2017"
    label var roa_i      "ROA（小数），2017"
    label var ato_i      "ATO：营业收入/总资产，2017"
    label var growth_i   "Growth：营业收入增长率，2017"
    keep focal partner pid t year break break1 break2 break3 first17 stkcd sic nnindcd fcty pcty ///
        tariff_i fem us impact post postimpact us_post us_tariff size_i lev_i roa_i ato_i growth_i
    order focal partner pid t year break break1 break2 break3 first17
    sort pid t
    compress
    if "`g'" == "ALL" {
        save "$CLEAN/panel_monthly.dta", replace
        di as txt "2017m1-2020m6 面板：关系对 x 月 = " _N
    }

    * ---- 5. 回归样本：控制变量缩尾后乘 postimpact；企业 x 月 ----
    keep if t <= tm(2019m12) & first17
    foreach v in size lev roa ato growth {
        quietly _pctile `v'_i, p(1 99)
        gen double w_`v'_i = min(max(`v'_i, r(r1)), r(r2)) if `v'_i < .
        label var w_`v'_i "`v'（样本内按观测 1%/99% 缩尾）"
        gen double post`v' = postimpact * w_`v'_i
    }
    label var postsize   "Post x Impact x Size"
    label var postlev    "Post x Impact x Lev"
    label var postroa    "Post x Impact x ROA"
    label var postato    "Post x Impact x ATO"
    label var postgrowth "Post x Impact x Growth"
    egen long firm_m = group(focal t)
    label var firm_m "A 股企业 x 月"
    sort pid t
    compress
    local fn = cond("`g'" == "ALL", "analysis_sample", "analysis_`g'")
    save "$CLEAN/`fn'.dta", replace

    egen byte tf = tag(focal)
    egen byte tc = tag(partner)
    egen byte tp = tag(pid)
    quietly count if tf
    local nf = r(N)
    quietly count if tc
    local nc = r(N)
    quietly count if tp
    local np = r(N)
    quietly count if tp & impact
    local nt = r(N)
    quietly count
    local no = r(N)
    quietly count if break
    local nb = r(N)
    di as txt "`g' 回归样本：A 股企业 `nf'，外国伙伴 `nc'，关系对 `np'（处理组 `nt'），关系对 x 月 `no'，断裂 `nb'"
}

log close l03
