;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;; heks-emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; heks-emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with heks-emacs.  If not, see <https://www.gnu.org/licenses/>.

sql-mode

(sel "SELECT " (s columns) " FROM " (s table) " WHERE " p ";" q)

(selo "SELECT " (s columns) " FROM " (s table) " ORDER BY " p ";" q)

(ins "INSERT INTO " (s table) " (" (s columns) ") VALUES (" p ");" q)

(upd "UPDATE " (s table) " SET " (s column) " = " p " WHERE " (s condition) ";" q)

(del "DELETE FROM " (s table) " WHERE " (s condition) ";" q)

(ct "CREATE TABLE " (s table) " (" n> (s column) " " (p "bigint") " PRIMARY KEY," n> p n ");" q)

(join "JOIN " (s table) " ON " (s table) "." (s column) " = " p)

(cte "WITH " (s name) " AS (" n> p n ")" n> "SELECT * FROM " (s name) ";" q)
