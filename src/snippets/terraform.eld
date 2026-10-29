;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

terraform-mode hcl-mode

(res "resource \"" (s type) "\" \"" (s name) "\" {" n> p n "}" q)

(dta "data \"" (s type) "\" \"" (s name) "\" {" n> p n "}" q)

(var "variable \"" (s name) "\" {" n> "type = " (p "string") n> p n "}" q)

(out "output \"" (s name) "\" {" n> "value = " p n "}" q)

(loc "locals {" n> p n "}" q)

(mod "module \"" (s name) "\" {" n> "source = \"" (p) "\"" n> p n "}" q)

(prv "provider \"" (s name) "\" {" n> p n "}" q)

(rm "required_providers {" n> (s name) " = {" n> "source  = \"" (p "hashicorp/aws") "\"" n> "version = \"" (p "~> 5.0") "\"" n> "}" n "}" q)
