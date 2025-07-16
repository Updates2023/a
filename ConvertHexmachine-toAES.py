from binascii import unhexlify, hexlify

from impacket.krb5 import constants
from impacket.krb5.crypto import Key, string_to_key
from Cryptodome.Hash import MD4

allciphers = {
	'rc4_hmac_nt': int(constants.EncryptionTypes.rc4_hmac.value),
	'aes128_hmac': int(constants.EncryptionTypes.aes128_cts_hmac_sha1_96.value),
	'aes256_hmac': int(constants.EncryptionTypes.aes256_cts_hmac_sha1_96.value)
}


def printKerberosKeys(password, salt):
	for name, cipher in allciphers.items():
		if cipher == 23:
			md4 = MD4.new()
			md4.update(password)
			key = Key(cipher, md4.digest())
		else:
			fixedPassword = password.decode('utf-16-le', 'replace').encode('utf-8', 'replace')
			key = string_to_key(cipher, fixedPassword, salt)

		print(f'    * {name}: {hexlify(key.contents).decode("utf-8")}')


def printMachineKerberosKeys(domain, hostname, hexpassword):
	salt = b'%shost%s.%s' % (domain.upper().encode('utf-8'), hostname.lower().encode('utf-8'), domain.lower().encode('utf-8'))
	rawpassword = unhexlify(hexpassword)
	print(f'{domain.upper()}\\{hostname.upper()}$')
	print(f'    * Salt: {salt.decode("utf-8")}')
	printKerberosKeys(rawpassword, salt)


def printUserKerberosKeys(domain, username, rawpassword):
	salt = b'%s%s' % (domain.upper().encode('utf-8'), username.encode('utf-8'))
	rawpassword = rawpassword.encode('utf-16-le')
	print(f'{domain.upper()}\\{username}')
	print(f'    * Salt: {salt.decode("utf-8")}')
	printKerberosKeys(rawpassword, salt)




printUserKerberosKeys("VENED.NL","SVC_OSD-SCCM-DOMAINJ",'I?D"ee&3/;lG5jw+.[=4')

#printMachineKerberosKeys("SEVENKINGDOMS.LOCAL","SEVENKINGDOMS","")