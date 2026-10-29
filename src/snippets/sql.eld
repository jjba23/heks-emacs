;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

sql-mode

(sel "SELECT " (s columns) " FROM " (s table) " WHERE " p ";" q)

(selo "SELECT " (s columns) " FROM " (s table) " ORDER BY " p ";" q)

(ins "INSERT INTO " (s table) " (" (s columns) ") VALUES (" p ");" q)

(upd "UPDATE " (s table) " SET " (s column) " = " p " WHERE " (s condition) ";" q)

(del "DELETE FROM " (s table) " WHERE " (s condition) ";" q)

(ct "CREATE TABLE " (s table) " (" n> (s column) " " (p "bigint") " PRIMARY KEY," n> p n ");" q)

(join "JOIN " (s table) " ON " (s table) "." (s column) " = " p)

(cte "WITH " (s name) " AS (" n> p n ")" n> "SELECT * FROM " (s name) ";" q)
