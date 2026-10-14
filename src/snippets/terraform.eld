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

terraform-mode hcl-mode

(res "resource \"" (s type) "\" \"" (s name) "\" {" n> p n "}" q)

(dta "data \"" (s type) "\" \"" (s name) "\" {" n> p n "}" q)

(var "variable \"" (s name) "\" {" n> "type = " (p "string") n> p n "}" q)

(out "output \"" (s name) "\" {" n> "value = " p n "}" q)

(loc "locals {" n> p n "}" q)

(mod "module \"" (s name) "\" {" n> "source = \"" (p) "\"" n> p n "}" q)

(prv "provider \"" (s name) "\" {" n> p n "}" q)

(rm "required_providers {" n> (s name) " = {" n> "source  = \"" (p "hashicorp/aws") "\"" n> "version = \"" (p "~> 5.0") "\"" n> "}" n "}" q)
