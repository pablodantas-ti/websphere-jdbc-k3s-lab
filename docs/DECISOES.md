# Decisões de arquitetura

## WebSphere Traditional

O objetivo é estudar o produto tradicional: console administrativo, wsadmin, escopos, JDBC providers, J2C e pools. O projeto não substitui esse objetivo por Liberty e não configura Network Deployment, Deployment Manager ou cluster WAS.

## Configuração reproduzível

O contêiner inicial era configurado pelo console para explorar os conceitos. Um reboot da VM mostrou que a camada gravável não era uma estratégia de persistência. O projeto passou a definir aplicação e DataSource no build e a aplicar credenciais na inicialização.

## ConfigMap e imagem

A correção de autenticação foi validada por ConfigMap para evitar reconstruir uma imagem grande durante o diagnóstico. O repositório mantém o mesmo arquivo no build e no ConfigMap, gerado a partir do fonte. A mudança do ConfigMap exige recriar o pod porque o arquivo é montado com subPath.

## Secret no runtime

O build usa apenas um marcador de senha não funcional. A senha real entra no alias antes de iniciar o servidor. A gravação é verificada por comparação interna com o Secret; apenas o resultado é registrado. O Secret administrativo é separado do Secret PostgreSQL.

## Pool gerenciado pelo WAS

O provider usa PGConnectionPoolDataSource. O WebSphere controla o pool; a aplicação fecha a Connection ao final, devolvendo-a ao pool. O código também fecha Statement e ResultSet, limita linhas e define timeout de consulta.

## Banco interno e acesso externo por túnel

PostgreSQL é ClusterIP e não recebe NodePort ou LoadBalancer. O console e a aplicação são acessados por port-forward associado a loopback e, quando necessário, túnel SSH. O laboratório não abre o banco na rede externa.

## Persistência local

O PVC do PostgreSQL resiste à recriação do pod. O provisionador local-path depende do disco do node; alta disponibilidade e backup não são fornecidos por esse mecanismo.

## Validação em duas etapas

O build valida a carga básica do driver e a configuração offline. O teste final exige uma consulta pela JSP usando o DataSource. Node Ready, pod Running ou teste SQL com usuário administrativo não comprovam a integração da aplicação.
