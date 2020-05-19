

Libname cc "C:\Users\fxg180000\Desktop\Project\Data" ;

/******* Import all the data *********/

 /* Import the groc store data */
 DATA groc_store; 
 infile "C:\Users\fxg180000\Desktop\Project\Data\saltsnck_groc" firstobs = 2 ;
 INPUT IRI_KEY WEEK SY GE VEND  ITEM  UNITS DOLLARS  F$ D PR ;
 upc_new = cats(of SY GE VEND  ITEM ) ;
 drop SY GE VEND ITEM  ;
 RUN;

  Proc print data = groc_store (obs = 3);
 run;

 /* import the data of product snack details */
 proc import datafile  =  'C:\Users\fxg180000\Desktop\Project\Data\prod_saltsnck.xls'
 out  =  prod_saltsnck1
 dbms  =  xls
 replace;
 run;

 /* collaborate the brands names */
data product_saltsnack ; 
set prod_saltsnck1 ;
upc_new = cats(of SY GE VEND  ITEM ) ;
length Brand $ 50;
 if L5 in ('DORITOS WOW','DORITOS TOPPERS','DORITOS THINS','DORITOS SUNSNACK','DORITOS SNACK KIT','DORITOS ROLLITOS','DORITOS NATURAL',
			   'DORITOS LIGHT','DORITOS EXTREMES','DORITOS EDGE','DORITOS CRUNCH PACK','DORITOS 3DS','DORITOS 100 CALORIE PACK','DORITOS',	
			   'CHEETOS DORITOS','BAKED DORITOS')
			   then Brand = 'DORITOS';
else if L5 in ('TOSTITOS WOW','TOSTITOS TOPPERS','TOSTITOS SUNSNACK','TOSTITOS SNACK KIT','TOSTITOS SENSATIONS','TOSTITOS SCOOPS',	
			   'TOSTITOS SANTA FE GOLD','TOSTITOS NATURAL','TOSTITOS LIGHT','TOSTITOS GOLD','TOSTITOS EDGE','TOSTITOS','BAKED TOSTITOS',
				'ALL TOSTITOS PRODUCTS')
				then Brand = 'TOSTITOS';
else Brand = L5;
where L2 = "TORTILLA/TOSTADA CHIPS" ;
drop L1 L9 Level UPC SY GE VEND ITEM _STUBSPEC_1431RC COOKING_METHOD SALT_SODIUM_CONTENT ;
run;

 Proc print data = product_saltsnack (obs = 3);
 run;

/* Import Delivery Store data details */
DATA Store_details; 
infile "C:\Users\fxg180000\Desktop\Project\Data\Delivery_Stores" firstobs = 2  ;
INPUT iri_key 1-7 OU $ 9-10 EST_ACV 12-19 Market_Name $ 21-44 Open 46-49 Clsd 51-54 MskdName $;
RUN;

 Proc print data = Store_details (obs = 4);
 run;

 /****************************/
/* Combine data */

/* combine groc and the prod details */

proc sql ;
create table groc_prod as select a.* , b.* from groc_store a , product_saltsnack b 
where a.upc_new = b.upc_new ;
quit;

proc print data = groc_prod (obs = 5) ;
run;

/* combine the groc strore, product and the location details */
proc sql ;
create table groc_prod_loc as select a.* , b.* from groc_prod a , Store_details b 
where a.iri_key = b.iri_key and Brand = 'TOSTITOS' ;
quit;

proc print data = groc_prod_loc (obs = 6) ;
run;


/**************************************************************************/
/* 1) Analyzing the data */

/* Analyse the groc store data*/

/* find the top 5 brands */
proc sql;
select Brand , sum(Dollars) from groc_prod 
group by Brand order by 2 DESC ;
quit;

/* Finf top brands and include everything else in other */
data store_groc_prod  ;
set groc_prod ;
Length Final_Brand $ 50 ;
if Brand = 'TOSTITOS' then Final_Brand = 'TOSTITOS';
else if Brand = 'DORITOS' then Final_Brand = 'DORITOS';
else if Brand = 'SANTITAS' then Final_Brand = 'SANTITAS';
else if Brand = 'PRIVATE LABEL' then Final_Brand = 'PRIVATE LABEL';
else if Brand = 'MISSION' then Final_Brand = 'MISSION';
else Final_Brand = 'OTHER' ;
run;

proc print data = store_groc_prod (obs = 5) ;
run;

/* calculate the market share*/
proc sql;
create table Top_brands_sales_groc as select Final_Brand , sum(Dollars) as Sales, 
(sum(dollars)/(select sum(dollars) from store_groc_prod))*100 as Share
from store_groc_prod 
group by Final_Brand order by 2 DESC ;
quit;

proc print data = store_groc_prod (obs = 5);
run;

/* draw bar chart for the tota sales*/                                                                                                         
proc gchart data = Top_brands_sales_groc;  
title2 "(Top Brands Sales in Groc Store)"; 
format Sales dollar8.; 
hbar3d Final_Brand / sumvar=Sales patternid = midpoint descending width=3 ;                                                                                             
run;   

 /* Generate pie chart to know about the market share nlpctn7.1 */
proc gchart data=Top_brands_sales_groc;
   format Share  dollar20.2;
   pie3d Final_Brand / sumvar=Share coutline=black value=arrow
           			 percent=arrow noheading percent=inside plabel=(height=7pt)
                     slice=inside value=none name='PieChart';
 run;


/* sales of the package type */

 /*only doritos Data */
 data doritos_groc_prod ;
 set store_groc_prod ;
 where Final_Brand = 'TOSTITOS ' ;
 run;

 /* we cannot find the sales with respect to the package because the BAG is the one that is most used 
 hence the sales of it will be maximum and same for the fat_content most of the data is missing so we cannot use analyze it
 but the third feature of the scent is the important one */

 proc freq data = doritos_groc_prod;
 table Package ;
 run;

 proc freq data = doritos_groc_prod;
 table flavor_scent ;
 run;

 proc freq data = doritos_groc_prod;
 table fat_content ;
 run;


 /* analyse of the scent */
proc sql;
create table sales_flavor_scent as select flavor_scent , sum(dollars)as sales from doritos_groc_prod
group by flavor_scent 
order  by 2 DESC;
quit;

proc print data = sales_flavor_scent ;  
run;

/* 5 scents sold most*/
data top_scent ;
set doritos_groc_prod ;
if  flavor_scent in ("NACHO CHEESE" , "COOLER RANCH" , "NACHO CHEESIER" , "4 CHEESES" , "SPICY NACHO" );
run;

proc print data = top_scent ;  
run;
 
/* check if the sales of scent significantly different*/
proc glm data = top_scent;
class flavor_scent ;
model dollars = flavor_scent;
LSMEANS flavor_Scent / ADJUST = T ;
run;


/* location that has the most sales */
proc sql;
select Market_Name, sum(dollars) from groc_prod_loc group by Market_Name order  by 2 DESC;
run;

data data_Markets ;
set groc_prod_loc ;
if Market_Name = "LOS ANGELES" or Market_Name = "SAN DIEGO" or Market_Name = "NEW YORK" or 
				  Market_Name = "BOSTON" or Market_Name = "DETROIT";
run;

proc means data = data_Markets ;
class Market_Name ;
var Dollars ;
run;


/* check if sales are statistically significant*/

proc glm data = data_Markets;
class Market_Name ;
model Dollars = Market_Name;
LSMEANS Market_Name / ADJUST = T ;
run;


/* Weekly sales and prices of our products */
data Avgere_Prices ;
set doritos_groc_prod ;
avg_prc = (Dollars/Units) / vol_eq ;
run;

proc means data = Avgere_Prices mean ;
class Week  Final_Brand ;
var avg_prc ;
output out = average_sales_week Mean = Average ;
run;

/* plot the pricer*/
proc sgplot data=average_sales_week;
   title 'Avg price for 7 brand per week';
   series x= week y= Average / group = Final_Brand name='grouping';
   keylegend 'grouping' ;
   YAXIS Label = 'Average Price';
   XAXIS TYPE = DISCRETE GRID; 
run;


/* sales with the time */
proc means data = doritos_groc_prod sum ;
class Week  Final_Brand ;
var Dollars ;
output out = sales_t sum = sum_sale ;
run;

/* plot the sales*/
proc sgplot data=sales_t;
   title 'Avg price for 7 brand per week';
   series x= week y= sum_sale / group = Final_Brand name='grouping';
   keylegend 'grouping' ;
   YAXIS Label = 'Average Sales';
   XAXIS TYPE = DISCRETE GRID; 
run;


/***************************************************/
/* First Model - What factors effect the sales */

proc freq data = groc_prod_loc ;
table f ;
run;

/* creating dummy variable for Column feature*/
DATA groc_prod_loc_f ;
set groc_prod_loc;
IF f = 'A+' THEN f_plus = 1;  ELSE f_plus = 0;
  IF f = 'A' THEN f_large = 1; ELSE f_large = 0;
 IF f = 'B' THEN f_medium = 1; ELSE f_medium = 0;	
 IF f = 'NONE' THEN f_none = 1; ELSE f_none = 0;	
 if f = 'NONE' then feature1 = 0 ; else feature1 = 1 ;
RUN;

proc print data =  groc_prod_loc_f (obs = 5);
run;

/*Create PPU by formula ((dollars/units)/vol_eq), Display, nd PR Dummy*/

proc printto log="C:\Users\fxg180000\Desktop\Project.log";
run;
data groc_prod_loc_f_d_pp;
set groc_prod_loc_f;
AvgPPU = ((dollars/units)/vol_eq);
if d = 0 then DISPLAY = 0;else DISPLAY = 1;
if PR = 1 then Price_Reduced = 1;else Price_Reduced = 0;
put DISPLAY Price_Reduced AvgPPU;
run;
proc printto;
run;

proc print data = groc_prod_loc_f_d_pp (obs = 5) ;
run;

/*Checking missing data in Panel_demo file*/
proc means data=groc_prod_loc_f_d_pp NMISS N; 
run;
/* no data is missing*/

proc panel data=grocprodloc_f_d_pp plots =None;       
id IRI_KEY WEEK;       
model TotalSales = AvgPrice AvgDisplay Avg_f_plus Avg_f_large Avg_f_medium Avg_f_none Avg_Price_Reduced
					 /  fixtwo ; 
run;
/* there is no missing value*/


* running random effect two way model*/
proc panel data = drugprodloc_f_d_pp plots = None;       
id IRI_KEY WEEK;       
model TotalSales = AvgPrice AvgDisplay Avg_f_plus Avg_f_large Avg_f_medium Avg_Price_Reduced /  rantwo ; 
run;


/*As Hausman test rejecting the null so we will run Fixed effect*/
/* running random effect two way model*/
proc panel data=drugprodloc_f_d_pp plots =None;       
id IRI_KEY WEEK;       
model TotalSales = AvgPrice AvgDisplay Avg_f_plus Avg_f_large Avg_f_medium Avg_Price_Reduced/  fixtwo ; 
run;


/* PS III: clustering*/
/********************************************RFM***************************************************************/

/* import the data of demographics */
 proc import datafile  =  'C:\Users\fxg180000\Desktop\Project\Data\ads_demo3.csv'
 out  =  Household_panel
 dbms  =  csv
 replace;
 run;

 /* only take the required columns*/
data Household_panel1;
set Household_panel(Drop = Panelist_Type COUNTY  
MALE_SMOKE FEM_SMOKE Language HISP_FLAG HISP_CAT HH_Head_Race__RACE2_ Microwave_Owned_by_HH market_based_upon_zipcode);
run;

/* import the panel data */
data drug_panel;
infile 'C:\Users\fxg180000\Desktop\Project\Data\saltsnck_PANEL_GR.dat'
delimiter ='09'x firstobs=2 missover;
input Panelist_ID WEEK UNITS OUTLET $ DOLLARS IRI_KEY COLUPC;
run;

/* merge the demographics and the panel data */
 proc sql;
create table panel_demo as select a.* , b.* from drug_panel a , Household_panel1 b 
where a.Panelist_ID = b.Panelist_ID ;
quit;

proc print data = panel_demo (obs = 5) ;
run;

/*import the product saltsnack data */
proc import datafile  =  'C:\Users\fxg180000\Desktop\Project\Data\prod_saltsnck.xls'
 out  =  prod_saltsnck1
 dbms  =  xls
 replace;
 run;

 /* collaborate the brands names */
data product_saltsnack ; 
set prod_saltsnck1 ;
length Brand $ 50;
/*upc_new1 = substr(upc_new,verify(upc_new,'0')); */

 if L5 in ('DORITOS WOW','DORITOS TOPPERS','DORITOS THINS','DORITOS SUNSNACK','DORITOS SNACK KIT','DORITOS ROLLITOS','DORITOS NATURAL',
			   'DORITOS LIGHT','DORITOS EXTREMES','DORITOS EDGE','DORITOS CRUNCH PACK','DORITOS 3DS','DORITOS 100 CALORIE PACK','DORITOS',	
			   'CHEETOS DORITOS','BAKED DORITOS')
			   then Brand = 'DORITOS';
else if L5 in ('TOSTITOS WOW','TOSTITOS TOPPERS','TOSTITOS SUNSNACK','TOSTITOS SNACK KIT','TOSTITOS SENSATIONS','TOSTITOS SCOOPS',	
			   'TOSTITOS SANTA FE GOLD','TOSTITOS NATURAL','TOSTITOS LIGHT','TOSTITOS GOLD','TOSTITOS EDGE','TOSTITOS','BAKED TOSTITOS',
				'ALL TOSTITOS PRODUCTS')
				then Brand = 'TOSTITOS';
else Brand = L5;
where L2 = "TORTILLA/TOSTADA CHIPS" ;
run;

/* Find top brands and include everything else in other */
data product_saltsnack1  ;
set product_saltsnack ;
Length Final_Brand $ 50 ;
if Brand = 'TOSTITOS' then Final_Brand = 'TOSTITOS';
else if Brand = 'DORITOS' then Final_Brand = 'DORITOS';
else if Brand = 'SANTITAS' then Final_Brand = 'SANTITAS';
else if Brand = 'HERRS' then Final_Brand = 'HERRS';
else Final_Brand = 'OTHER' ;
run;

/* create new vend and the item codes for upc to get the same format as the upc panel */
data product_saltsnack2;
set product_saltsnack1;
VEND_new=put(input(VEND,best5.),z5.);
run;

data product_saltsnack3;
set product_saltsnack2;
ITEM_new=put(input(ITEM,best5.),z5.);
run;

/* creating new column in product dataset for merging purpose*/
data product_saltsnack4;
set product_saltsnack3;
if SY ='88' then upc_new =cats(of SY GE VEND_new ITEM_new);
else upc_new = cats(of  GE VEND_new ITEM_new);
 run;

 proc print data = product_saltsnack4 (obs = 5) ;
 run;

 /* keep the required cl */
data product_saltsnack5;
set product_saltsnack4;
keep VOL_EQ FLAVOR_SCENT final_brand upc_new;
run;

proc print data=product_saltsnack5(obs=4);
run;


/* creating new column in product dataset for merging purpose*/
data product_saltsnack6 ;
set product_saltsnack5;
upc=input(upc_new,best13.);
run;


/* merge the panel demo groc products data */
proc sql;
create table merge_final as select a.*,b.* from panel_demo a , product_saltsnack6 b
where a.COLUPC = b.upc ;
run;

/* take the doritos data*/
data merge_final;
set merge_final;
where final_brand ne ' ' ;
where final_brand = 'DORITOS' ;
run;

proc print data = merge_final ( obs = 5) ;
run;

/* total number of rows for the brand*/
proc freq data = merge_final ;
table final_brand;
run;


/* RFM and customer Segmentation */
%aaRFM;
%EM_RFM_CONTROL
(
   Mode = T,              
   InData = merge_final,            
   CustomerID = Panelist_ID,        
   N_R_Grp = 4,         
   N_F_Grp = 4,         
   N_M_Grp = 4,         
   BinMethod = I,          
   PurchaseDate = WEEK,      
   PurchaseAmt = DOLLARS,       
   SetMiss = N,                                                         
   SummaryFunc = SUM,
   MostRecentDate = ,
   NPurchase = ,         
   TotPurchaseAmt = ,  
   MonetizationMap = Y, 
   BinChart = Y,        
   BinTable = Y,        
   OutData = RFM_RESULTS,           
   Recency_Score = recency_score,     
   Frequency_Score = frequency_score,   
   Monetary_Score = monetary_score,    
   RFM_Score = rfm_score           
);

proc print data=RFM_RESULTS(obs=10);
run;

/* find the corre between the scores */
proc corr data = RFM_RESULTS ;
var recency_score frequency_score monetary_score ;
run;

proc fastclus data=RFM_RESULTS maxclusters=4 mean=temp out= rfm_output_v1;
var recency_score frequency_score monetary_score;
run;

proc print data=rfm_output_v1(obs=10);
run;

PROC SQL;
CREATE VIEW rfm_output AS
SELECT a.*,b.rfm_score,b.Cluster FROM merge_final a inner join
rfm_output_v1 b 
on b.panelist_id=a.panelist_id;
QUIT;

proc print data=rfm_output(obs=10);run;

/*Frequency of different clusters*/
proc freq data=rfm_output ORDER=FREQ ; 
table Cluster;
run;

proc sql ;
create table fre as select Cluster , (count(panelist_id)/(select count(*) from rfm_output))*100 as count from  rfm_output group  by cluster ;
quit;

proc print data = fre;
run;

data cluster1;
set rfm_output;
if Cluster=1;
run;
data cluster2;
set rfm_output;
if Cluster=2;
run;
data cluster3;
set rfm_output;
if Cluster=3;
run;
data cluster4;
set rfm_output;
if Cluster=4;
run;

proc print data=cluster1(obs=20); var cluster rfm_score;run;
proc print data=cluster2(obs=20); var cluster rfm_score;run;
proc print data=cluster3(obs=20); var cluster rfm_score;run;
proc print data=cluster4(obs=20);run;

/*Descriptive statistics on clustered data*/
/*Sales Analysis across Cluster*/
PROC means DATA=rfm_output;
VAR dollars;
class cluster; 
RUN;

proc freq data= rfm_output;
table cluster*Combined_Pre_Tax_Income_of_HH/ out=CellCountsTrain;
run;

proc freq data= rfm_output;
table cluster*Children_Group_Code/ out=CellCountsTrain;
run;

proc freq data= rfm_output;
table cluster*Family_Size/ out=CellCountsTrain;
run;

proc freq data= rfm_output;
table cluster*HH_OCC/ out=CellCountsTrain;
run;

/* Distribution of Age across cluster*/
proc freq data= rfm_output;
table cluster*HH_AGE/ out=CellCountsTrain;
run;

/*Distribution of Occupation across Cluster*/

proc freq data= rfm_output;
table cluster*HH_EDU/ out=CellCountsTrain;
run;


proc freq data= rfm_output;
table cluster*HH_RACE/ out=CellCountsTrain;
run;

proc freq data= rfm_output;
table cluster*Type_of_Residential_Possession/ out=CellCountsTrain;
run;

proc freq data= rfm_output;
table cluster*Male_Working_Hour_Code/ out=CellCountsTrain;
run;

proc freq data= rfm_output;
table cluster*Female_Working_Hour_Code/ out=CellCountsTrain;
run;


/* 3rd Model: multilogit*/
/********************************************Multilogit Code*************************************/

/* import of the groc store data */
DATA groc_store; 
 infile "C:\Users\fxg180000\Desktop\Project\Data\saltsnck_groc" firstobs = 2 ;
 INPUT IRI_KEY WEEK SY GE VEND  ITEM  UNITS DOLLARS  F$ D PR ;
 RUN;

 /* modifications in the columns to create a new upc column*/
data groc_store1;
set groc_store;
VEND_new= put(VEND,z5.);
run;

proc print data = groc_store1 (obs = 2) ;
run;

data groc_store2;
set groc_store1;
ITEM_new=put(ITEM,z5.);
run;

/* creating new column in grocery data for merging purpose*/
data groc_store3;
set groc_store2;
if SY ='88' then upc_new =cats(of SY GE VEND_new ITEM_new);
else upc_new = cats(of  GE VEND_new ITEM_new);
 run;

data groc_store;
set groc_store3;
keep IRI_KEY WEEK UNITS DOLLARS F D PR upc_new;
run;

proc print data = groc_store (obs = 3) ;
run;

/* import product saltsnack details data */
proc import datafile  =  'C:\Users\fxg180000\Desktop\Project\Data\prod_saltsnck.xls'
 out  =  prod_saltsnck1
 dbms  =  xls
 replace;
 run;

 /* collaborate the brands names */
data product_saltsnack ; 
set prod_saltsnck1 ;
length Brand $ 50;
/*upc_new1 = substr(upc_new,verify(upc_new,'0')); */

if L5 in ('DORITOS WOW','DORITOS TOPPERS','DORITOS THINS','DORITOS SUNSNACK','DORITOS SNACK KIT','DORITOS ROLLITOS','DORITOS NATURAL',
			   'DORITOS LIGHT','DORITOS EXTREMES','DORITOS EDGE','DORITOS CRUNCH PACK','DORITOS 3DS','DORITOS 100 CALORIE PACK','DORITOS',	
			   'CHEETOS DORITOS','BAKED DORITOS')
			   then Brand = 'DORITOS';
else if L5 in ('TOSTITOS WOW','TOSTITOS TOPPERS','TOSTITOS SUNSNACK','TOSTITOS SNACK KIT','TOSTITOS SENSATIONS','TOSTITOS SCOOPS',	
			   'TOSTITOS SANTA FE GOLD','TOSTITOS NATURAL','TOSTITOS LIGHT','TOSTITOS GOLD','TOSTITOS EDGE','TOSTITOS','BAKED TOSTITOS',
				'ALL TOSTITOS PRODUCTS')
				then Brand = 'TOSTITOS';
else Brand = L5;
where L2 = "TORTILLA/TOSTADA CHIPS" ;
run;

/* Find top brands and include everything else in other */
data product_saltsnack1  ;
set product_saltsnack ;
Length Final_Brand $ 50 ;
if Brand = 'TOSTITOS' then Final_Brand = 'TOSTITOS';
else if Brand = 'DORITOS' then Final_Brand = 'DORITOS';
else if Brand = 'SANTITAS' then Final_Brand = 'SANTITAS';
else if Brand = 'PRIVATE LABEL' then Final_Brand = 'PRIVATE LABEL';
else if Brand = 'MISSION' then Final_Brand = 'MISSION';
else Final_Brand = 'OTHER' ;
run;

/* count of the man brands */
proc freq data = product_saltsnack1;
table final_brand ;
run;

/* modifications in the columns to create a new upc column*/
data product_saltsnack2;
set product_saltsnack1;
VEND_new=put(input(VEND,best5.),z5.);
run;

data product_saltsnack3;
set product_saltsnack2;
ITEM_new=put(input(ITEM,best5.),z5.);
run;

/* creating new column in product dataset for merging purpose*/
data product_saltsnack4;
set product_saltsnack3;
if SY ='88' then upc_new =cats(of SY GE VEND_new ITEM_new);
else upc_new = cats(of  GE VEND_new ITEM_new);
 run;

proc print data=product_saltsnack4(obs=4);run;

/* keep only the required columns */
data product_saltsnack5;
set product_saltsnack4;
keep VOL_EQ final_brand FLAVOR_SCENT upc_new;
run;

proc print data=product_saltsnack5(obs=4);run;

/* combine the grocery scanner data to detail of product saltsnack data */
proc sql ;
create table groc_prod as select a.* , b.* from groc_store a , product_saltsnack5 b 
where a.upc_new = b.upc_new ;
quit;

proc print data=groc_prod(obs=6);run;

/* create a new column of price per unite */
data groc_prod;
set groc_prod;
PPU = ((dollars/units)/vol_eq);
run;

/* import the data of demographics  */
 proc import datafile  =  'C:\Users\fxg180000\Desktop\Project\Data\ads_demo3.csv'
 out  =  demo
 dbms  =  csv
 replace;
 run;

 /* keep the required fields*/
data Household_demo;
set demo;
keep  Panelist_ID Family_Size Combined_Pre_Tax_Income_of_HH HH_AGE Children_Group_Code Marital_Status;
run;

/* rename one of the column name */
data household_demo_logit;
set Household_demo(rename= (Combined_Pre_Tax_Income_of_HH=HH_Income));
run;

proc print data = household_demo_logit (obs = 5) ;
run;

/* import the panel data */
data groc_panel;
infile 'C:\Users\fxg180000\Desktop\Project\Data\saltsnck_PANEL_GR.dat'
delimiter ='09'x firstobs=2 missover;
input Panelist_ID WEEK UNITS OUTLET $ DOLLARS IRI_KEY COLUPC;
run;

/* combine demographics and the panel data */
 proc sql;
create table panel_demo as select a.* , b.* from groc_panel a , household_demo_logit b 
where a.Panelist_ID = b.Panelist_ID ;
quit;

proc print data = panel_demo (obs = 5) ;
run;

/* chage the type of the upc in the prod groc data */
data groc_prod ;
set groc_prod;
upc=input(upc_new,best13.);
run;

/* merge the panel demo groc and prod data */
proc sql;
create table merge_final as select a.*,b.* from panel_demo a ,groc_prod b
where a.IRI_KEY = b.IRI_KEY
and  a.WEEK = b.WEEK
and  a.COLUPC = b.upc ;
run;

proc print data = merge_final ( obs = 5) ;
run;

proc freq data = merge_final2 ;
table final_brand;
run;

/* there are 5 brands in total that we are getting after combining 
	all data - TOSTITOS, DORITOS, PRIVATE LABEL, SANTITAS and OTHER */

/* check if there is any missing data */
proc means data = merge_final nmiss n ;
run;
/* there is no missing data in the final table  we have */

/* create a dummy variable of a feature */
data merge_final;
set merge_final;
if F='NONE' then Feature= 0;
else Feature =1;
run;

data merge_final2 ;
set merge_final;
F_price = Feature*PPU ;
D_Price = D*PPU ;
Price_sq = PPU*PPU ;
F_pr = Feature*PR ;
D_Pr = D*PR ;
run;

proc print data = merge_final3 (obs = 2);
run;

/* know the means of all variables*/
proc means data=merge_final2;
run;
/*Logit model */

proc logistic data = merge_final2 ;
class final_brand(ref = "OTHER");
model final_brand =   Feature D PR PPU  F_pr Price_sq /link=glogit;
run;

data merge_final3 ;
set merge_final2;
if final_brand in( 'TOSTITOS' , 'DORITOS') ;
if final_brand  = 'DOSTITOS' then a  = 1 ; else a = 0;
run;

proc logistic data=merge_final3;
model  a(desc) = Feature D PR PPU  F_pr Price_sq;
run;

proc logistic data = merge_final3 ;
class final_brand(ref = "TOSTITOS");
model final_brand =   Feature D PR PPU  F_pr /link=glogit;
run;

/* get the means of the data */
proc sql ;
create table al_mean_products as select final_brand, avg(PPU) as avg from merge_final2
group by final_brand ;
quit;

proc print data = al_mean_products;
run;

proc sql ;
create table al_mean_products as select final_brand, avg(D) as avg from merge_final2
group by final_brand ;
quit;

proc print data = al_mean_products;
run;

proc sql ;
create table al_mean_products as select final_brand, avg(Feature) as avg from merge_final2
group by final_brand ;
quit;

proc print data = al_mean_products;
run;

