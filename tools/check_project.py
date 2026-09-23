"""Check cross-file contracts without requiring WAS, Kubernetes or credentials."""
import ast
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def check():
    deployment = json.loads((ROOT / 'k8s/was-deployment.json').read_text())
    patch = json.loads((ROOT / 'k8s/was-patch.json').read_text())
    service = json.loads((ROOT / 'k8s/was-service.json').read_text())
    container = deployment['spec']['template']['spec']['containers'][0]
    patched = patch['spec']['template']['spec']['containers'][0]
    assert container['image'] == patched['image']
    for name in ['01-build.sh', '02-deploy.sh']:
        assert 'tag=' + container['image'] in (ROOT / 'scripts' / name).read_text()
    assert deployment['spec']['selector']['matchLabels'] == service['spec']['selector']
    assert container['imagePullPolicy'] == 'Never'
    assert deployment['spec']['progressDeadlineSeconds'] > 1800
    assert {p['port'] for p in service['spec']['ports']} == {9043, 9443}
    volumes = {v['name']: v for v in deployment['spec']['template']['spec']['volumes']}
    assert volumes['lab-db']['secret']['secretName'] == 'postgres-lab-auth'
    assert volumes['lab-auth-code']['configMap']['name'] == 'was-lab-runtime-auth-v2'
    assert any(m['subPath'] == 'runtime-auth.py' for m in container['volumeMounts'] if 'subPath' in m)

    source = ROOT / 'app/src/main/webapp'
    web = ET.parse(source / 'WEB-INF/web.xml')
    ns = {'j': 'http://xmlns.jcp.org/xml/ns/javaee'}
    assert web.find('.//j:res-ref-name', ns).text == 'jdbc/LabDS'
    assert web.find('.//j:res-auth', ns).text == 'Container'
    assert web.find('.//j:cookie-config', ns) is None
    binding = ET.parse(source / 'WEB-INF/ibm-web-bnd.xml')
    ref = binding.getroot()[0]
    assert ref.attrib == {'name': 'jdbc/LabDS', 'binding-name': 'jdbc/LabDS'}
    assert 'java:comp/env/jdbc/LabDS' in (source / 'jdbc.jsp').read_text()

    runtime = (ROOT / 'image/runtime-auth.py').read_text()
    assert runtime.index('AdminConfig.save()') < runtime.index('LAB_AUTH_SECRET_MATCH=SIM')
    assert runtime.index('LAB_AUTH_SECRET_MATCH=SIM') < runtime.index("open('/tmp/lab-auth-ok'")
    assert 'unicode(decoded) != password' in runtime
    validator = (ROOT / 'scripts/03-validar.sh').read_text()
    assert 'Host: localhost:9443' in validator
    assert "--since-time=" in validator

    for path in ROOT.rglob('*'):
        if not path.is_file() or '.git' in path.parts or '__pycache__' in path.parts:
            continue
        if path.suffix == '.py':
            ast.parse(path.read_text(encoding='utf-8'), filename=str(path))
        if path.suffix == '.sh':
            assert b'\r\n' not in path.read_bytes(), 'CRLF in ' + str(path)
        if path.suffix == '.md':
            for link in re.findall(r'\]\(([^)]+)\)', path.read_text(encoding='utf-8')):
                if '://' not in link and not link.startswith('#'):
                    assert (path.parent / link.split('#')[0]).exists(), 'Broken link: ' + link
    print('PASS: manifests, image tags, JNDI binding, auth verification, validator, XML/Python syntax and documentation links')


if __name__ == '__main__':
    check()
