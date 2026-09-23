# Executed offline during image build. No real credentials belong here.
server = AdminConfig.getid('/Cell:DefaultCell01/Node:DefaultNode01/Server:server1/')
if not server:
    raise Exception('Expected server1 profile not found')
provider = AdminConfig.create('JDBCProvider', server, [
    ['name', 'PostgreSQL-Lab'],
    ['implementationClassName', 'org.postgresql.ds.PGConnectionPoolDataSource'],
    ['classpath', '/opt/IBM/WebSphere/AppServer/jdbc/postgresql.jar'],
    ['xa', 'false']])
ds = AdminConfig.create('DataSource', provider, [
    ['name', 'LabDS'], ['jndiName', 'jdbc/LabDS'],
    ['datasourceHelperClassname', 'com.ibm.websphere.rsadapter.GenericDataStoreHelper'],
    ['authDataAlias', 'DefaultNode01/labpostgres'], ['statementCacheSize', '10']])
pool = AdminConfig.showAttribute(ds, 'connectionPool')
poolattrs = [['minConnections', '0'], ['maxConnections', '5'], ['connectionTimeout', '15']]
if pool:
    AdminConfig.modify(pool, poolattrs)
else:
    AdminConfig.create('ConnectionPool', ds, poolattrs)
props = AdminConfig.showAttribute(ds, 'propertySet')
if not props:
    props = AdminConfig.create('J2EEResourcePropertySet', ds, [])
for name, kind, value in [
    ('serverName', 'java.lang.String', 'postgres-lab.websphere.svc.cluster.local'),
    ('portNumber', 'java.lang.Integer', '5432'),
    ('databaseName', 'java.lang.String', 'labdb'),
    ('connectTimeout', 'java.lang.Integer', '10'),
    ('socketTimeout', 'java.lang.Integer', '30')]:
    AdminConfig.create('J2EEResourceProperty', props, [
        ['name', name], ['type', kind], ['value', value], ['required', 'false']])
AdminConfig.create('MappingModule', ds, [
    ['mappingConfigAlias', 'DefaultPrincipalMapping'],
    ['authDataAlias', 'DefaultNode01/labpostgres']])
security = AdminConfig.getid('/Cell:DefaultCell01/Security:/')
if not security:
    raise Exception('Cell security configuration not found')
AdminConfig.create('JAASAuthData', security, [
    ['alias', 'DefaultNode01/labpostgres'], ['userId', 'waslab'],
    ['password', 'RUNTIME_SECRET_REQUIRED']])
AdminApp.install('/work/lab/was-lab.war', [
    '-appname', 'was-lab_war', '-contextroot', '/was-lab',
    '-node', 'DefaultNode01', '-server', 'server1',
    '-MapWebModToVH', [['.*', '.*', 'default_host']],
    '-MapResRefToEJB', [['.*', '.*', '.*', 'jdbc/LabDS', 'javax.sql.DataSource',
        'jdbc/LabDS', '', '', '']]])
AdminConfig.save()
f = open('/work/lab/build-ok', 'w')
f.write('provider, datasource and application configured\n')
f.close()
print('LAB_BUILD_OK')
