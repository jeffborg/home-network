Cert manager

use xca database on dropbox

tls.key in secret is the secret key for the intermediate ca in the xca db
tls.crt is 2 certs
  1. root cert
  2. intermediate cert (the one the secret key can sign certs for + this one is signed by the root)

Order is important it has to be this order otherwise the issued certs won't work!

