;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

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
