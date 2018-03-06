CREATE  OR REPLACE
PACKAGE &owner..aval_util

/*
|| Package used for automatic payment processing
|| Created by Shmyg
|| LMD by Shmyg 22.01.2002
*/

/*
fill_customer_payments - procedure to find customer_id for customer who payed
some money. Looks for data inserted in umc_customer_paymentss (custcode and
dn_num) and tries to find corresponding customer_id for every record
*/

AS
        file_id        NUMBER := 0;

	PROCEDURE	fill_customer_payments;

END     aval_util;
/

SHOW ERROR
