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

kotlin-mode kotlin-ts-mode

(cls "class " (s name) " {" n> p n "}" q)

(data "data class " (s name) "(" n> (s fields) n ")" q)

(iface "interface " (s name) " {" n> p n "}" q)

(obj "object " (s name) " {" n> p n "}" q)

(fn "fun " (s name) "(" (s args) "): " (p "Unit") " {" n> p n "}" q)

(sfn "fun " (s name) "(" (s args) "): " (p "Unit") " =" n> p)

(vl "val " (s name) ": " (p "String") " = " p)

(vr "var " (s name) ": " (p "String") " = " p)

(main "fun main() {" n> p n "}" q)

(when "when (" (s subject) ") {" n> p n "}" q)

(tst "@Test" n> "fun " (s name) "() {" n> p n "}" q)

(ctrl "@RestController" n> "class " (s name) "Controller {" n> p n "}" q)

(svc "@Service" n> "class " (s name) "Service {" n> p n "}" q)

(repo "@Repository" n> "interface " (s name) "Repository : JpaRepository<" (p "Entity, Long") ">" q)

(entity "@Entity" n> "class " (s name) "(" n> (s fields) n ") {" n> p n "}" q)

(boot "@SpringBootApplication" n> "class " (s Application) "Application" n n> "fun main(args: Array<String>) {" n> "runApplication<" (s Application) "Application>(*args)" n> "}" q)
