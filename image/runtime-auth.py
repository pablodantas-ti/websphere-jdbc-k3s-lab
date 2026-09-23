# Run offline before the server starts. Never print credentials.
from javax.xml.parsers import DocumentBuilderFactory
from java.io import File
from com.ibm.websphere.crypto import PasswordUtil

f = open('/run/lab-db/app-password', 'rb')
raw = f.read()
f.close()
password = raw.decode('UTF-8')
if not password:
    raise Exception('Empty database Secret')
found = 0
for item in AdminConfig.list('JAASAuthData').splitlines():
    if AdminConfig.showAttribute(item, 'alias') == 'DefaultNode01/labpostgres':
        AdminConfig.modify(item, [['userId', 'waslab'], ['password', password]])
        found = found + 1
if found != 1:
    raise Exception('Expected exactly one labpostgres authentication alias')
AdminConfig.save()

# AdminConfig masks password reads, so verify the persisted value privately.
path = '/opt/IBM/WebSphere/AppServer/profiles/AppSrv01/config/cells/DefaultCell01/security.xml'
factory = DocumentBuilderFactory.newInstance()
factory.setFeature('http://apache.org/xml/features/disallow-doctype-decl', True)
document = factory.newDocumentBuilder().parse(File(path))
elements = document.getElementsByTagName('*')
verified = 0
for i in range(elements.getLength()):
    element = elements.item(i)
    if element.getAttribute('alias') == 'DefaultNode01/labpostgres':
        stored = element.getAttribute('password')
        decoded = PasswordUtil.decode(stored)
        if decoded is None:
            decoded = stored
        if unicode(decoded) != password:
            raise Exception('LAB_AUTH_VERIFY_FAILED: persisted alias differs from Secret; server startup stopped')
        verified += 1
if verified != 1:
    raise Exception('LAB_AUTH_VERIFY_FAILED: expected exactly one persisted alias')
print('LAB_AUTH_SECRET_MATCH=SIM')
f = open('/tmp/lab-auth-ok', 'w')
f.write('ok\n')
f.close()
print('LAB_RUNTIME_AUTH_OK')
