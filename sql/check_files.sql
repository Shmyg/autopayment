/*
Script to check if we have loaded duplicate payment files
Created by Shmyg
LMD 10.12.2003 by Shmyg
*/

DECLARE
	
	-- We need to check all the files with '00' (just loaded) status 
	CURSOR	file_cur
	IS
	SELECT	up.file_id,
		TRUNC( up.entdate ),
		NVL( SUM( uc.amount ), 0 ),
		COUNT( uc.line_num )
	FROM	aval.umc_payment_files		up,
		aval.umc_customer_payments	uc
	WHERE	uc.file_id(+) = up.file_id
	AND	up.file_status = '00'
	GROUP	BY up.file_id,
		TRUNC( up.entdate );

	v_file_id	PLS_INTEGER;
	v_quantity	PLS_INTEGER;
	v_count		PLS_INTEGER;
	v_amount	NUMBER;
	v_entdate	DATE;

BEGIN

	OPEN	file_cur;
	LOOP
		FETCH	file_cur
		INTO	v_file_id,
			v_entdate,
			v_amount,
			v_quantity;
		
		EXIT	WHEN file_cur%NOTFOUND;

		SELECT	COUNT(*)
		INTO	v_count
		FROM	(
			SELECT	up.file_id,
				SUM( uc.amount ) AS amount,
				COUNT( uc.line_num ) AS quantity
			FROM	aval.umc_payment_files		up,
				aval.umc_customer_payments	uc
			WHERE	uc.file_id = up.file_id
			AND	TRUNC( up.entdate ) = v_entdate
			AND	up.file_status != '01'
			GROUP	BY up.file_id
			)	fs
		WHERE	fs.amount = v_amount
		AND	fs.quantity = v_quantity
		AND	file_id != v_file_id;
			
		IF	v_count > 0
		THEN
			UPDATE	aval.umc_payment_files
			SET	file_status = '10'
			WHERE	file_id = v_file_id;
		ELSE
			UPDATE	aval.umc_payment_files
			SET	file_status = '01'
			WHERE	file_id = v_file_id;
		END	IF;

	END	LOOP;
	CLOSE	file_cur;
	COMMIT;
END;
/