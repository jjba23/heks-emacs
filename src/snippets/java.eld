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

java-mode java-ts-mode

(cls "public class " (s name) " {" n> p n "}" q)

(itf "public interface " (s name) " {" n> p n "}" q)

(rec "public record " (s name) "(" n> p n ") {}" q)

(main "public static void main(String[] args) {" n> p n "}" q)

(mth "public " (p "void") " " (s name) "(" (s args) ") {" n> p n "}" q)

(fld "private " (p "String") " " (s name) ";")

(ctor "public " (s name) "(" (s args) ") {" n> p n "}" q)

(prt "System.out.println(" (p) ");")

(tst "@Test" n> "void " (s name) "() {" n> p n "}" q)

(spring "@SpringBootApplication" n> "public class " (s Application) " {" n> "public static void main(String[] args) {" n> "SpringApplication.run(" (s Application) ".class, args);" n> "}" n "}" q)
