/*
Script assigning payments for customers
Looks for payments from AVAL.UMC_CUSTOMER_PAYMENTS table
and tries to assign payment for every customer
$Author: shmyg $
$Date: 2004/01/14 08:41:46 $
*/

DECLARE

	-- Constants
	c_status_to_process	CONSTANT VARCHAR2(2) := '01';
	c_status_is_processed	CONSTANT VARCHAR2(2) := '02';
	c_status_with_warnings	CONSTANT VARCHAR2(2) := '03';

	-- Variables
	v_customer_id		NUMBER;
	v_amount		NUMBER;

	-- These are ROWIDs to make commits in cursors
	v_payment_rowid		UROWID;
	v_file_rowid		UROWID;

	i			PLS_INTEGER := 0;
	v_count			PLS_INTEGER := 0;
	v_file_id		PLS_INTEGER;

	-- These ones depend on if the customer has open order or not
	v_catype		PLS_INTEGER;
	v_careasoncode		PLS_INTEGER;
	v_close_orders		VARCHAR2(1);
	v_remark		VARCHAR2(30);

	-- Log variable to store flag if customer is successfully processed
	v_processed		VARCHAR2(1);

	v_gl_code		aval.umc_payment_files.gl_code%TYPE;
	v_err_message		aval.umc_customer_payments.err_message%TYPE;

	file_has_errors		BOOLEAN;
	
	-- Payment object which do real work
	payment		donor.payment_t := donor.payment_t
				(
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL	
				);

	-- Cursor for payment files which have been loaded and checked
	-- and to be processed now
	CURSOR	file_cur
	IS
	SELECT	file_id,
		gl_code,
		ROWID
	FROM	aval.umc_payment_files
	WHERE	gl_code IS NOT NULL
	AND	file_status = c_status_to_process;

	-- Cursor for payments for specified file
	CURSOR	payment_cur
		(
		p_file_id	NUMBER
		)
	IS
	SELECT	NVL( customer_id, 0 ), 
		amount,
		ROWID
	FROM	aval.umc_customer_payments
	WHERE	file_id = p_file_id
	AND	processed IS NULL;

	-- Function to check if customer is payment repsonsible
	FUNCTION	is_payment_responsible
		(
		i_customer_id	NUMBER
		)
	RETURN	BOOLEAN
	IS
		v_customer_id	NUMBER;
	BEGIN
		-- Just to trying to select data - if it's NO_DATA_FOUND,
		-- then customer is not payment responsible
		SELECT	customer_id
		INTO	v_customer_id
		FROM	customer_all
		WHERE	customer_id = i_customer_id
		AND	paymntresp = 'X';
		
		RETURN	TRUE;

	EXCEPTION
		WHEN	NO_DATA_FOUND
		THEN	RETURN	FALSE;
	END;

	-- Function to check if customer has open orders
	FUNCTION	has_open_orders
		(
		i_customer_id	NUMBER
		)
	RETURN	BOOLEAN
	IS
		v_customer_id	PLS_INTEGER;
	BEGIN
		-- Just to trying to select one open order. If there is
		-- NO_DATA_FOUND - there are no open orders at all
		SELECT	customer_id
		INTO	v_customer_id
		FROM	orderhdr_all
		WHERE	customer_id = i_customer_id
		AND	ohstatus = 'IN'
		AND	ohopnamt_gl > 0
		AND	ROWNUM = 1;

		RETURN	TRUE;

	EXCEPTION
		WHEN	NO_DATA_FOUND
		THEN	RETURN	FALSE;
	END;

BEGIN

	OPEN	file_cur;

	LOOP
		FETCH	file_cur
		INTO	v_file_id,
			v_gl_code,
			v_file_rowid;

		EXIT	WHEN file_cur%NOTFOUND;

		file_has_errors := FALSE;

		-- Looking for payments for this file
		OPEN	payment_cur ( v_file_id );
		LOOP

			FETCH	payment_cur
			INTO	v_customer_id,
				v_amount,
				v_payment_rowid;

			EXIT	WHEN payment_cur%NOTFOUND;

			-- Checking if customer is payment responsible
			IF	is_payment_responsible( v_customer_id )
			THEN
				-- Checking if customer has open orders
				IF	has_open_orders( v_customer_id )
				THEN
					-- He has them
					v_catype := 1;
					v_careasoncode := 17;
					v_close_orders := 'Y';
					v_remark := 'Automatic payment';

				ELSE
					-- Customer doesn't have open orders
					-- Assigning advance
					v_catype := 3;
					v_careasoncode := 19;
					v_close_orders := 'N';
					v_remark := 'Automatic advance';
				END	IF;

				BEGIN
					
				-- Here we need savepoint to roll the TX back in
				-- case of any error
				SAVEPOINT	start_tx;

				-- Inserting payment
				payment.insert_me
					(
					v_customer_id,
					v_amount,
					v_remark,
					v_remark,
					v_catype,
					v_careasoncode,
					v_gl_code,
					'9999984',
					SYSDATE,
					v_close_orders
					);

				v_err_message := payment.tx_id;
				v_processed := 'X';

				EXCEPTION

				-- Some error ocurred - rolling back and reporting
				WHEN	OTHERS
				THEN
					v_processed := 'E';
					v_err_message := SQLERRM;
					file_has_errors := TRUE;
					ROLLBACK TO start_tx;

				END;
			ELSE
				-- Customer is not payment responsible or null
				v_processed := 'E';
				v_err_message := 'Customer is unknown ' || 
					'or is not payment responsible';
				file_has_errors := TRUE;
			END	IF;

			-- Logging all the work we've done
			UPDATE	aval.umc_customer_payments
			SET	processed = v_processed,
				err_message = v_err_message
			WHERE	ROWID = v_payment_rowid;

		END	LOOP;
		CLOSE	payment_cur;

	-- Marking file as processed
	IF	file_has_errors
	THEN
		UPDATE	aval.umc_payment_files
		SET	file_status = c_status_with_warnings
		WHERE	ROWID = v_file_rowid;
	ELSE	
		UPDATE	aval.umc_payment_files
		SET	file_status = c_status_is_processed
		WHERE	ROWID = v_file_rowid;
	END	IF;

	COMMIT;

	END	LOOP;

	CLOSE	file_cur;

END;
/