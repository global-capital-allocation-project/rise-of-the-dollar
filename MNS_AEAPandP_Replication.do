* ---------------------------------------------------------------------------------------------------
* This code generates all tables and figures for the paper "The Rise of the Dollar and Fall of the 
* Euro as International Currencies", with the only exceptions being those analyses using SDC Platinum 
* data (in Sections 1 and A.1).  
*
* The code reads from the data files in the folder "Input_Data", but we cannot post SDC Platinum data 
* there, given our purchase agreement and licensing rules. Please contact the authors for more details 
* on those analyses.
* ---------------------------------------------------------------------------------------------------

* Set environment
clear all
set type double
set matsize 5000
set maxvar 32000
set more off
clear
cap mkdir graphs
cap mkdir logs

* Start logging
cap log close
log using "logs/Rise_of_the_Dollar_Replication", replace

* ---------------------------------------------------------------------------------------------------
* SECTIONS 2 AND A.2 ON INVOICING IN INTERNATIONAL TRADE
* ---------------------------------------------------------------------------------------------------

* Iterate over specifications
foreach drop04 in "" "drop04" {
	foreach maxgap in "100" "4" {

		* Read in the data
		import excel Input_Data/kaopen_2016.xls, sheet("Sheet1") firstrow clear
		keep cn ccode country_name
		duplicates drop
		save cn_concord, replace
		use Input_Data/From_Ito.dta, clear
		merge n:1 cn using cn_concord.dta, keep(3) nogen
		rm cn_concord.dta
		if "`drop04'"=="drop04" {
			drop if year<=2004
		}
		foreach dir in "exp" "imp" {
			foreach cur in "euro" "usd" {
				sort cn year
				gen lastnmyr_`dir'_`cur' = year if !missing(`dir'_`cur')
				by cn: replace lastnmyr_`dir'_`cur' = lastnmyr_`dir'_`cur'[_n-1] if missing(lastnmyr_`dir'_`cur')
				by cn: gen gap_`dir'_`cur' = lastnmyr_`dir'_`cur'-lastnmyr_`dir'_`cur'[_n-1]
				drop lastnmyr_`dir'_`cur'
				by cn: ipolate `dir'_`cur' year, generate(`dir'_`cur'_filled)
				replace `dir'_`cur' = `dir'_`cur'_filled
				drop `dir'_`cur'_filled
				gsort cn -year
				gen flag_`dir'_`cur' = 1 if gap_`dir'_`cur'>`maxgap'
				by cn: gen runflag_`dir'_`cur' = sum(flag_`dir'_`cur')
				by cn: replace `dir'_`cur' = . if runflag_`dir'_`cur'[_n-1]>=1 & cn==cn[_n-1]
			}
		}
		keep year cn exp_euro exp_usd imp_euro imp_usd country_name
		sort cn year
		save ci_invoice, replace
		import excel Input_Data/Exports_and_Imports_by_Areas_and_Co.xlsx, sheet("Exports, FOB") cellrange(B7:AC248) clear
		foreach var of varlist * {
			local yrtmp = `var'[1]
			local newlab = "yr`yrtmp'"
			rename `var' `newlab'
		}
		rename yr cty
		reshape long yr, i(cty) j(year)
		rename yr exports
		drop if missing(cty)
		destring exports, replace
		save dot, replace
		import excel Input_Data/Exports_and_Imports_by_Areas_and_Co.xlsx, sheet("Imports, CIF") cellrange(B7:AC248) clear
		foreach var of varlist * {
			local yrtmp = `var'[1]
			local newlab = "yr`yrtmp'"
			rename `var' `newlab'
		}
		rename yr cty
		reshape long yr, i(cty) j(year)
		rename yr imports
		drop if missing(cty)
		destring imports, replace
		merge 1:1 cty year using dot, keep(3) nogen
		rename cty country_name
		rm dot.dta
		replace country_name="Afghanistan" if country_name=="Afghanistan, I.R. of"
		replace country_name="Azerbaijan" if country_name=="Azerbaijan, Rep. of"
		replace country_name="Bahrain" if country_name=="Bahrain, Kingdom of"
		replace country_name="C?e d'Ivoire" if country_name=="Côte d'Ivoire"
		replace country_name="Cape Verde" if country_name=="Cabo Verde"
		replace country_name="Central African Republic" if country_name=="Central African Rep."
		replace country_name="China" if country_name=="China,P.R.: Mainland"
		replace country_name="Congo, Dem. Rep." if country_name=="Congo, Dem. Rep. of"
		replace country_name="Congo, Rep." if country_name=="Congo, Republic of"
		replace country_name="Egypt, Arab Rep." if country_name=="Egypt"
		replace country_name="Hong Kong, China" if country_name=="China,P.R.: Hong Kong"
		replace country_name="Iran, Islamic Rep." if country_name=="Iran, I.R. of"
		replace country_name="Korea, Rep." if country_name=="Korea, Republic of"
		replace country_name="Lao PDF" if country_name=="Lao People's Dem.Rep"
		replace country_name="Micronesia, Fed. Sts." if country_name=="Micronesia"
		replace country_name="S? Tom�and Principe" if country_name=="São Tomé & Príncipe"
		replace country_name="St. Vincent and the Grenadines" if country_name=="St. Vincent & Grens."
		replace country_name="Venezuela, RB" if country_name=="Venezuela, Rep. Bol."
		replace country_name="Yemen, Rep." if country_name=="Yemen, Republic of"
		merge 1:1 country_name year using ci_invoice, keep(3) nogen
		rm ci_invoice.dta
		drop if year<1991
		rename *_euro curr_shareEUR*
		rename *_usd curr_shareUSD*
		reshape long curr_shareEUR curr_shareUSD, i(country_name year) j(stk_flow) string
		gen trade = imports if stk_flow=="imp"
		replace trade = exports if stk_flow=="exp"
		replace stk_flow="Exports" if stk_flow=="exp"
		replace stk_flow="Imports" if stk_flow=="imp"
		drop imports exports
		rename country_name geo
		rename year time
		sort geo time
		keep geo time stk_flow curr_shareEUR curr_shareUSD trade
		drop if time<1999
		gen forave = trade if time<=2014
		bys geo stk_flow: egen ave_tr = mean(forave)
		drop forave
		gen in_eu = 0
		replace in_eu=1 if inlist(geo,"Austria","Belgium","Bulgaria","Croatia","Cyprus","Czech Republic")
		replace in_eu=1 if inlist(geo,"Denmark","Estonia","Finland","France","Germany","Greece")
		replace in_eu=1 if inlist(geo,"Hungary","Ireland","Italy","Latvia","Lithuania","Luxembourg","Malta")
		replace in_eu=1 if inlist(geo,"Netherlands","Poland","Portugal","Romania","Slovakia","Slovak Republic")
		replace in_eu=1 if inlist(geo,"Slovenia","Spain","Sweden","United Kingdom")
		foreach restrict in "0" "in_eu" {
			foreach flow in "Imp" "Exp" {
				foreach cur in "USD" "EUR" {
						sum curr_share`cur' if time==2010 & substr(stk_flow,1,3)=="`flow'" & `restrict'==0
						local `flow'`cur'_unwtd_2010`restrict' = `r(mean)'
						sum curr_share`cur' if time==2010 & substr(stk_flow,1,3)=="`flow'" & `restrict'==0 [aw=trade]
						local `flow'`cur'_wtd_2010`restrict' = `r(mean)'
				}
			}
		}
		sum time
		local firstyr = `r(min)'
		local lastyr = `r(max)'
		foreach dir in "Imp" "Exp" {
			foreach treat in "wtd" "unwtd" {
				foreach curr in "USD" "EUR" {
					foreach restrict in "0" "in_eu" {
						gen `dir'_`curr'_`treat'`restrict' = .
					}
				}
			}
		}
		xi i.time
		foreach restrict in "0" "in_eu" {
			foreach dir in "Imp" "Exp" {
				foreach curr in "USD" "EUR" {
					areg curr_share`curr' _I* if substr(stk_flow,1,3)=="`dir'" & `restrict'==0, absorb(geo)
						forvalues yr = `firstyr'(1)`lastyr' {
							capture replace `dir'_`curr'_unwtd`restrict' = _b[_Itime_`yr'] + _b[_cons] if time==`yr'
							capture replace `dir'_`curr'_unwtd`restrict' = _b[_cons] if time==`firstyr' & missing(`dir'_`curr'_unwtd)
						}
					areg curr_share`curr' _I* if substr(stk_flow,1,3)=="`dir'" & `restrict'==0 [aw=ave_tr], absorb(geo)
						forvalues yr = `firstyr'(1)`lastyr' {
							capture replace `dir'_`curr'_wtd`restrict' = _b[_Itime_`yr'] + _b[_cons] if time==`yr'
							capture replace `dir'_`curr'_wtd`restrict' = _b[_cons] if time==`firstyr' & missing(`dir'_`curr'_wtd)
						}
				}
			}
		}
		keep Imp_USD* Imp_EUR* Exp_USD* Exp_EUR* time
		duplicates drop
		sort time
		foreach restrict in "0" "in_eu" {
			foreach flow in "Imp" "Exp" {
				foreach cur in "USD" "EUR" {
					di "`restrict'`flow'`cur'"
					sum `flow'_`cur'_unwtd`restrict' if time==2010
					replace `flow'_`cur'_unwtd`restrict' = `flow'_`cur'_unwtd`restrict' + (``flow'`cur'_unwtd_2010`restrict'' - `r(mean)')
					sum `flow'_`cur'_wtd`restrict' if time==2010
					replace `flow'_`cur'_wtd`restrict' = `flow'_`cur'_wtd`restrict' + (``flow'`cur'_wtd_2010`restrict'' - `r(mean)')
				}
			}
		}

		rename *in_eu *_noeu
		
		* Plot of Imports (Weighted and Unweighted)
		if "`drop04'"=="drop04" {
			line Imp_USD_wtd0 Imp_EUR_wtd0 Imp_USD_unwtd0 Imp_EUR_unwtd0 time, ylabel(0(0.2)1) xlabel(2005(5)2015) xtitle("") graphregion(color(white)) legend(label(1 "USD Share (Weighted) ") label(2 "EUR Share (Weighted)") label(3 "USD Share (Unweighted)") label(4 "EUR Share (Unweighted)") rows(2)) lpattern(solid solid dash dash) lcolor(red blue red blue)
		}
		else {
			line Imp_USD_wtd0 Imp_EUR_wtd0 Imp_USD_unwtd0 Imp_EUR_unwtd0 time, ylabel(0(0.2)1) xlabel(2000(5)2015) xtitle("") graphregion(color(white)) legend(label(1 "USD Share (Weighted) ") label(2 "EUR Share (Weighted)") label(3 "USD Share (Unweighted)") label(4 "EUR Share (Unweighted)") rows(2)) lpattern(solid solid dash dash) lcolor(red blue red blue)
		}
		graph export graphs\trade_imp_`maxgap'`drop04'.eps, as(eps) replace
		graph export graphs\trade_imp_`maxgap'`drop04'.pdf, as(pdf) replace

		* Plot of Exports (Weighted and Unweighted)
		if "`drop04'"=="drop04" {
			line Exp_USD_wtd0 Exp_EUR_wtd0 Exp_USD_unwtd0 Exp_EUR_unwtd0 time, ylabel(0(0.2)1) xlabel(2005(5)2015) xtitle("") graphregion(color(white)) legend(label(1 "USD Share (Weighted) ") label(2 "EUR Share (Weighted)") label(3 "USD Share (Unweighted)") label(4 "EUR Share (Unweighted)") rows(2)) lpattern(solid solid dash dash) lcolor(red blue red blue)
		}
		else {
			line Exp_USD_wtd0 Exp_EUR_wtd0 Exp_USD_unwtd0 Exp_EUR_unwtd0 time, ylabel(0(0.2)1) xlabel(2000(5)2015) xtitle("") graphregion(color(white)) legend(label(1 "USD Share (Weighted) ") label(2 "EUR Share (Weighted)") label(3 "USD Share (Unweighted)") label(4 "EUR Share (Unweighted)") rows(2)) lpattern(solid solid dash dash) lcolor(red blue red blue)
		}
		graph export graphs\trade_exp_`maxgap'`drop04'.eps, as(eps) replace
		graph export graphs\trade_exp_`maxgap'`drop04'.pdf, as(pdf) replace

		* Plot of Imports (No EU, Weighted and Unweighted)
		if "`drop04'"=="drop04" {
			line Imp_USD_wtd_noeu Imp_EUR_wtd_noeu Imp_USD_unwtd_noeu Imp_EUR_unwtd_noeu time, ylabel(0(0.2)1) xlabel(2005(5)2015) xtitle("") graphregion(color(white)) legend(label(1 "USD Share (Weighted) ") label(2 "EUR Share (Weighted)") label(3 "USD Share (Unweighted)") label(4 "EUR Share (Unweighted)") rows(2)) lpattern(solid solid dash dash) lcolor(red blue red blue)
		}
		else {
			line Imp_USD_wtd_noeu Imp_EUR_wtd_noeu Imp_USD_unwtd_noeu Imp_EUR_unwtd_noeu time, ylabel(0(0.2)1) xlabel(2000(5)2015) xtitle("") graphregion(color(white)) legend(label(1 "USD Share (Weighted) ") label(2 "EUR Share (Weighted)") label(3 "USD Share (Unweighted)") label(4 "EUR Share (Unweighted)") rows(2)) lpattern(solid solid dash dash) lcolor(red blue red blue)
		}
		graph export graphs\trade_imp_noeu_`maxgap'`drop04'.eps, as(eps) replace
		graph export graphs\trade_imp_noeu_`maxgap'`drop04'.pdf, as(pdf) replace

		* Plot of Exports (No EU, Weighted and Unweighted)
		if "`drop04'"=="drop04" {
			line Exp_USD_wtd_noeu Exp_EUR_wtd_noeu Exp_USD_unwtd_noeu Exp_EUR_unwtd_noeu time, ylabel(0(0.2)1) xlabel(2005(5)2015) xtitle("") graphregion(color(white)) legend(label(1 "USD Share (Weighted) ") label(2 "EUR Share (Weighted)") label(3 "USD Share (Unweighted)") label(4 "EUR Share (Unweighted)") rows(2)) lpattern(solid solid dash dash) lcolor(red blue red blue)
		}
		else {
			line Exp_USD_wtd_noeu Exp_EUR_wtd_noeu Exp_USD_unwtd_noeu Exp_EUR_unwtd_noeu time, ylabel(0(0.2)1) xlabel(2000(5)2015) xtitle("") graphregion(color(white)) legend(label(1 "USD Share (Weighted) ") label(2 "EUR Share (Weighted)") label(3 "USD Share (Unweighted)") label(4 "EUR Share (Unweighted)") rows(2)) lpattern(solid solid dash dash) lcolor(red blue red blue)
		}
		graph export graphs\trade_exp_noeu_`maxgap'`drop04'.eps, as(eps) replace
		graph export graphs\trade_exp_noeu_`maxgap'`drop04'.pdf, as(pdf) replace

		* Plot of Imports (With and Without EU, Unweighted)
		if "`drop04'"=="drop04" {
			line Imp_USD_unwtd0 Imp_EUR_unwtd0 Imp_USD_unwtd_noeu Imp_EUR_unwtd_noeu time, ylabel(0(0.2)1) xlabel(2005(5)2015) xtitle("") graphregion(color(white)) legend(label(1 "USD Share") label(2 "EUR Share") label(3 "USD Share (No EU)") label(4 "EUR Share (No EU)") rows(2)) lpattern(solid solid dash dash ) lcolor(red blue red blue)
		}
		else {
			line Imp_USD_unwtd0 Imp_EUR_unwtd0 Imp_USD_unwtd_noeu Imp_EUR_unwtd_noeu time, ylabel(0(0.2)1) xlabel(2000(5)2015) xtitle("") graphregion(color(white)) legend(label(1 "USD Share") label(2 "EUR Share") label(3 "USD Share (No EU)") label(4 "EUR Share (No EU)") rows(2)) lpattern(solid solid dash dash ) lcolor(red blue red blue)
		}
		graph export graphs\trade_imp_allunwt_`maxgap'`drop04'.eps, as(eps) replace
		graph export graphs\trade_imp_allunwt_`maxgap'`drop04'.pdf, as(pdf) replace

		* Plot of Exports (With and Without EU, Unweighted)
		if "`drop04'"=="drop04" {
			line Exp_USD_unwtd0 Exp_EUR_unwtd0 Exp_USD_unwtd_noeu Exp_EUR_unwtd_noeu time, ylabel(0(0.2)1) xlabel(2005(5)2015) xtitle("") graphregion(color(white)) legend(label(1 "USD Share") label(2 "EUR Share") label(3 "USD Share (No EU)") label(4 "EUR Share (No EU)") rows(2)) lpattern(solid solid dash dash ) lcolor(red blue red blue)
		}
		else {
			line Exp_USD_unwtd0 Exp_EUR_unwtd0 Exp_USD_unwtd_noeu Exp_EUR_unwtd_noeu time, ylabel(0(0.2)1) xlabel(2000(5)2015) xtitle("") graphregion(color(white)) legend(label(1 "USD Share") label(2 "EUR Share") label(3 "USD Share (No EU)") label(4 "EUR Share (No EU)") rows(2)) lpattern(solid solid dash dash ) lcolor(red blue red blue)
		}
		graph export graphs\trade_exp_allunwt_`maxgap'`drop04'.eps, as(eps) replace
		graph export graphs\trade_exp_allunwt_`maxgap'`drop04'.pdf, as(pdf) replace

		* Plot of Imports (With and Without EU, Weighted)
		if "`drop04'"=="drop04" {
			line Imp_USD_wtd0 Imp_EUR_wtd0 Imp_USD_wtd_noeu Imp_EUR_wtd_noeu time, ylabel(0(0.2)1) xlabel(2005(5)2015) xtitle("") graphregion(color(white)) legend(label(1 "USD Share") label(2 "EUR Share") label(3 "USD Share (No EU)") label(4 "EUR Share (No EU)") rows(2)) lpattern(solid solid dash dash ) lcolor(red blue red blue)
		}
		else {
			line Imp_USD_wtd0 Imp_EUR_wtd0 Imp_USD_wtd_noeu Imp_EUR_wtd_noeu time, ylabel(0(0.2)1) xlabel(2000(5)2015) xtitle("") graphregion(color(white)) legend(label(1 "USD Share") label(2 "EUR Share") label(3 "USD Share (No EU)") label(4 "EUR Share (No EU)") rows(2)) lpattern(solid solid dash dash ) lcolor(red blue red blue)
		}
		graph export graphs\trade_imp_allwt_`maxgap'`drop04'.eps, as(eps) replace
		graph export graphs\trade_imp_allwt_`maxgap'`drop04'.pdf, as(pdf) replace

		* Plot of Exports (With and Without EU, Weighted)
		if "`drop04'"=="drop04" {
			line Exp_USD_wtd0 Exp_EUR_wtd0 Exp_USD_wtd_noeu Exp_EUR_wtd_noeu time, ylabel(0(0.2)1) xlabel(2005(5)2015) xtitle("") graphregion(color(white)) legend(label(1 "USD Share") label(2 "EUR Share") label(3 "USD Share (No EU)") label(4 "EUR Share (No EU)") rows(2)) lpattern(solid solid dash dash ) lcolor(red blue red blue)
		}
		else {
			line Exp_USD_wtd0 Exp_EUR_wtd0 Exp_USD_wtd_noeu Exp_EUR_wtd_noeu time, ylabel(0(0.2)1) xlabel(2000(5)2015) xtitle("") graphregion(color(white)) legend(label(1 "USD Share") label(2 "EUR Share") label(3 "USD Share (No EU)") label(4 "EUR Share (No EU)") rows(2)) lpattern(solid solid dash dash ) lcolor(red blue red blue)
		}
		graph export graphs\trade_exp_allwt_`maxgap'`drop04'.eps, as(eps) replace
		graph export graphs\trade_exp_allwt_`maxgap'`drop04'.pdf, as(pdf) replace
	}
}

* ---------------------------------------------------------------------------------------------------
* SECTION 3 -- FX VOLUME
* ---------------------------------------------------------------------------------------------------
insheet using Input_Data/table-d11_3.csv, comma clear
keep if v1=="Frequency" | inlist(substr(v9,1,3),"USD","EUR","TO1")
drop v1-v8 v10-v15
rename v9 currency
forvalues j=1(1)50 {
	capture local name = v`j'[1]
	capture rename v`j' fxvol`name'
}
drop if _n==1
reshape long fxvol, i(currency) j(year)
destring fxvol, force replace
replace currency = substr(currency,1,3)
reshape wide fxvol, i(year) j(currency) string
renpfix fxvol
gen USD_share = USD/TO1/2
gen EUR_share = EUR/TO1/2
drop TO1
gen Ratio = USD/EUR
drop if missing(EUR)
order year USD USD_share EUR EUR_share Ratio

* ---------------------------------------------------------------------------------------------------
* SECTION 4 -- RESERVES
* ---------------------------------------------------------------------------------------------------
import excel "Input_Data/Table_1_World_Currency_Composition.xlsx", sheet("World") clear
keep if (_n>=22 & _n<=37) | _n==5
drop A
replace B="var" if _n==1
foreach x of varlist _all {
	local temp=`x'[1]
	rename `x' q`temp'
}	
drop if _n==1
rename qvar var
reshape long q, i(var) j(quarter) str
drop if var==""
split quarter, p("Q")
drop quarter
rename quarter1 year
rename quarter2 quarter
replace quarter="4" if quarter==""
keep if quarter=="4"
gen datestr="30mar"+year if quarter=="1"
replace datestr="30jun"+year if quarter=="2"
replace datestr="30sep"+year if quarter=="3"
replace datestr="30dec"+year if quarter=="4"
gen date=date(datestr,"DMY")
format date %td
order date
drop year quarter datestr
gen quarter=qofd(date)
format quarter %tq
order quarter
rename q share
replace var="AUD" if regexm(var,"Austra")==1
replace var="CAD" if regexm(var,"Canadia")==1
replace var="CNY" if regexm(var,"Chinese")==1
replace var="DEM" if regexm(var,"Deutsc")==1
replace var="ECU" if regexm(var,"ECU")==1
replace var="FRF" if regexm(var,"Fren")==1
replace var="JPY" if regexm(var,"Japan")==1
replace var="NLG" if regexm(var,"Netherl")==1
replace var="CHF" if regexm(var,"Swiss")==1
replace var="USD" if regexm(var,"U.S.")==1
replace var="EUR" if regexm(var,"euros")==1
replace var="other" if regexm(var,"other")==1
replace var="GBP" if regexm(var,"pound")==1
replace var="alloc" if regexm(var,"of A")==1
replace var="unalloc" if regexm(var,"of U")==1
drop date
destring share, force replace
reshape wide share, i(quarter) j(var) str
renpfix share
gen usd_rel_eur=USD/(USD+EUR)
gen eur_rel_usd=EUR/(USD+EUR)
local lineloc = tq(2008q3)
replace USD = USD/100
replace EUR = EUR/100
gen OTHER = 1-USD-EUR
gen year = year(dofq(quarter))
line USD EUR year if eur~=., ylabel(0(0.2)1) xtitle("") graphregion(color(white)) legend(label(1 "USD Share") label(2 "EUR Share") rows(1)) lpattern(solid dash) lcolor(red blue)
graph export graphs\reserves_abs2.eps, as(eps) replace
graph export graphs\reserves_abs2.pdf, as(pdf) replace

* ---------------------------------------------------------------------------------------------------
* SECTION 5 -- PEGS
* ---------------------------------------------------------------------------------------------------
import excel Input_Data/236_data.xlsx, sheet("Master") cellrange(A7:GQ81) firstrow clear
rename * peg*
rename pegISO3Code year
keep if _n>=5
reshape long peg, i(year) j(country) string
destring year, force replace
gen usdpegs = 1 if peg=="USD"
gen eurpegs = 1 if peg=="EUR"
keep if year==1999 | year==2015
keep if usdpegs==1 | eurpegs==1
drop peg
reshape wide usdpegs eurpegs, i(country) j(year)
count if eurpegs1999==1
count if eurpegs2015==1
count if usdpegs1999==1
count if usdpegs2015==1
count if eurpegs2015==1 & missing(eurpegs1999)
list country if eurpegs2015==1 & missing(eurpegs1999)
count if usdpegs2015==1 & missing(usdpegs1999)
list country if usdpegs2015==1 & missing(usdpegs1999)
count if missing(eurpegs2015) & eurpegs1999==1
list country if missing(eurpegs2015) & eurpegs1999==1
count if missing(usdpegs2015) & usdpegs1999==1
list country if missing(usdpegs2015) & usdpegs1999==1

* Close logging
log close

