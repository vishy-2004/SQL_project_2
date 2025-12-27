/*Task 13: Identify Members with Overdue Books
Write a query to identify members who have overdue books (assume a 30-day return period).
Display the member's_id,
member's name, book title, issue date, and days overdue.*/
SELECT 
    ist.issued_member_id,
    m.member_name,
    bk.book_title,
    ist.issued_date,
    -- rs.return_date,
    CURRENT_DATE - ist.issued_date as over_dues_days
FROM issued_status as ist
JOIN 
members as m
    ON m.member_id = ist.issued_member_id
JOIN 
books as bk
ON bk.isbn = ist.issued_book_isbn
LEFT JOIN 
return_status as rs
ON rs.issued_id = ist.issued_id
WHERE 
    rs.return_date IS NULL
    AND
    (CURRENT_DATE - ist.issued_date) > 30
ORDER BY 1;

/*Task 14: Update Book Status on Return
Write a query to update the status of books in the books table to "Yes"
when they are returned (based on entries in the return_status table).*/
CREATE OR REPLACE PROCEDURE add_return_records(p_return_id VARCHAR(10), p_issued_id VARCHAR(10), p_book_quality VARCHAR(10))
LANGUAGE plpgsql
AS $$

DECLARE
    v_isbn VARCHAR(50);
    v_book_name VARCHAR(80);
    
BEGIN
    INSERT INTO return_status(return_id, issued_id, return_date, book_quality)
    VALUES
    (p_return_id, p_issued_id, CURRENT_DATE, p_book_quality);

    SELECT 
        issued_book_isbn,
        issued_book_name
        INTO
        v_isbn,
        v_book_name
    FROM issued_status
    WHERE issued_id = p_issued_id;

    UPDATE books
    SET status = 'yes'
    WHERE isbn = v_isbn;

    RAISE NOTICE 'Thank you for returning the book: %', v_book_name;
    
END;
$$


-- Testing FUNCTION add_return_records

issued_id = IS135
ISBN = WHERE isbn = '978-0-307-58837-1'

SELECT * FROM books
WHERE isbn = '978-0-307-58837-1';

SELECT * FROM issued_status
WHERE issued_book_isbn = '978-0-307-58837-1';

SELECT * FROM return_status
WHERE issued_id = 'IS135';
CALL add_return_records('RS138', 'IS135', 'Good');
CALL add_return_records('RS148', 'IS140', 'Good');

/*Task 15: Branch Performance Report
Create a query that generates a performance report for each branch, showing the number of books issued,
the number of books returned, and the total revenue generated from book rentals.*/
CREATE TABLE branch_reports AS SELECT 
    b.branch_id,
    b.manager_id,
    COUNT(ist.issued_id) as number_book_issued,
    COUNT(rs.return_id) as number_of_book_return,
    SUM(bk.rental_price) as total_revenue
FROM issued_status as ist
JOIN employees as e
ON e.emp_id = ist.issued_emp_id JOIN branch as b
ON e.branch_id = b.branch_id
LEFT JOIN return_status as rs
ON rs.issued_id = ist.issued_id JOIN books as bk
ON ist.issued_book_isbn = bk.isbn GROUP BY 1, 2;
SELECT * FROM branch_reports;

/*Task 16: CTAS: Create a Table of Active Members
Use the CREATE TABLE AS (CTAS) statement to create a new table active_members
containing members who have issued at least one book in the last 2 months.*/

CREATE TABLE active_members
AS
SELECT * FROM members
WHERE member_id IN (SELECT 
                        DISTINCT issued_member_id   
                    FROM issued_status
                    WHERE issued_date >= CURRENT_DATE - INTERVAL '2 month');
SELECT * FROM active_members;

/*Task 17: Find Employees with the Most Book Issues Processed
Write a query to find the top 3 employees who have processed the most book issues.
Display the employee name, number of books processed, and their branch.*/
SELECT e.emp_name,b.*,
COUNT(ist.issued_id) as no_book_issued
FROM issued_status as ist JOIN employees as e
ON e.emp_id = ist.issued_emp_id
JOIN branch as b ON e.branch_id = b.branch_id
GROUP BY 1, 2


/*Task 18: Identify Members Issuing High-Risk Books
Write a query to identify members who have issued books more than 
twice with the status "damaged" in the books table. Display the member name, 
book title, and the number of times they've issued damaged books.*/

select m.member_name,b.book_title,count(re.book_quality),count(iss.issued_id) 
from issued_status as iss join 
members as m on iss.issued_member_id=m.member_id join
books as b on iss.issued_book_isbn=b.isbn left join return_status as re on
iss.issued_id=re.issued_id where re.book_quality='Damaged' group by 1,2 having count(iss.issued_id)>=2;

select mem.member_id, mem.member_name, bk.book_title, count(ist.issued_book_isbn)
from return_status as rs
join issued_status as ist on ist.issued_id = rs.issued_id
join members as mem on mem.member_id = ist.issued_member_id
join books as bk on ist.issued_book_isbn = bk.isbn
where rs.book_quality = 'Damaged' 
group by mem.member_id, bk.book_title
having count(ist.issued_book_isbn) > 2;

/*Task 19: Stored Procedure Objective: Create a stored procedure to
manage the status of books in a library system. Description:
Write a stored procedure that updates the status of a book in the library based on its issuance.
The procedure should function as follows: The stored procedure should take the book_id as an input 
parameter. The procedure should first check if the book is available (status = 'yes'). If the book 
is available, it should be issued, and the status in the books table should be updated to 'no'.
If the book is not available (status = 'no'), the procedure should return an error message indicating
that the book is currently not available.*/
create or replace procedure update_status(p_issued_id varchar(13),p_member_id varchar(13),p_issued_book_isbn varchar(20),p_issued_emp_id varchar(18))
language plpgsql
as $$
declare 
v_status varchar(10);
begin
--checking if book is available 
select status into v_status 
from books where isbn=p_issued_book_isbn;

if v_status='yes' then
insert into issued_status(issued_id,issued_member_id,issued_date,issued_book_isbn,issued_emp_id)
values(p_issued_id,p_member_id,current_date,p_issued_book_isbn,p_issued_emp_id);
 UPDATE books
    SET status = 'no'
    WHERE isbn = p_issued_book_isbn;
raise notice 'book added successfully of isbn :%',p_issued_book_isbn;
else 
raise notice 'requested book is not available %',p_issued_book_isbn;
end if;
end;
$$;
/*isbn=978-0-330-25864-8
issued_id=IS106
meember_id
emp_id=EI104
*/
select * from issued_status where issued_book_isbn='978-0-7432-7357-1';
call update_status('IS136','C107','978-0-7432-7357-1','E102')

/*Task 20: Create Table As Select (CTAS) Objective: 
Create a CTAS (Create Table As Select) query to identify overdue books and calculate fines.

Description: Write a CTAS query to create a new table that lists each member and the books
they have issued but not returned within 30 days. The table should include: The number of overdue
books. The total fines, with each day's fine calculated at $0.50. The number of books issued by each member.
The resulting table should show: Member ID Number of overdue-book books Total fines*/
 select m.member_id,count(iss.issued_book_isbn) as number_of_book_issued
 ,sum(extract(day from (current_date-(iss.issued_date+interval '30 days')))*0.5) as
 total_fine from issued_status as iss join members as m on m.member_id=iss.issued_member_id
 join books as b on b.isbn=iss.issued_book_isbn left join return_status as ret 
 on ret.issued_id=iss.issued_id where 
 ret.return_date is null
 and extract(day from(current_date-(iss.issued_date+interval '30 days')))>0 group by 1;
 







