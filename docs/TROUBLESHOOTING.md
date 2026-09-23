# Diagnóstico por camada

O laboratório foi construído com falhas reais de instalação, rede e autenticação. As observações abaixo distinguem o que foi confirmado do que permaneceu como hipótese.

## K3s reiniciando durante o startup

**Observado:** API indisponível, reinícios do serviço e mensagem do kubelet recusando cgroup v1.

**Resolução validada:** ativação de cgroup v2 no RHEL e reinício da VM. Confirmação com `stat -fc %T /sys/fs/cgroup` retornando `cgroup2fs`, node Ready e `/readyz` retornando ok. Os erros de readiness da API eram consequência da inicialização interrompida.

## Download lento e ContainerCreating

**Observado:** downloads lentos na VM, erros RX na interface e consumo elevado de CPU em interrupções. NAT melhorou a conexão no ambiente original. Durante a preparação de imagens, o estado ContainerCreating não indicava sozinho a causa.

**Investigação:** eventos do pod, log do containerd, espaço/inodes, CPU e etapas de download/descompactação. Não atribuir toda demora à rede nem tratar alteração do modo de rede como solução universal.

```bash
k3s kubectl describe pod -n websphere -l app=was
k3s kubectl get events -n websphere --sort-by=.metadata.creationTimestamp
df -h /var/lib/rancher/k3s
df -i /var/lib/rancher/k3s
```

## DataSource e senha desaparecendo depois do reboot

**Observado:** mesmo nome de pod, novo contêiner, nova senha administrativa e configuração manual ausente. O pod não montava armazenamento do perfil WAS. O banco preservou seus dados no PVC.

**Resolução:** imagem com aplicação e recursos JDBC, credenciais externas e inicialização por script. O projeto não promete persistência de qualquer edição feita pelo console: a configuração que sobrevive é a definida nos fontes.

## JNDI não encontrado

O código procura `java:comp/env/jdbc/LabDS`, que precisa estar declarado no web.xml e ligado ao DataSource `jdbc/LabDS`. Verificar o escopo de server1, o nome exato e o binding do módulo. A classe do driver é configurada no provider e não dentro do WAR.

## IllegalAccessError no driver

Um carregamento inicial produziu IllegalAccessError envolvendo `org.postgresql.Driver` e `Driver$1`. A causa exata não foi comprovada isoladamente. A configuração posterior em imagem reproduzível conectou com sucesso; isso não prova que uma troca de versão tenha sido a causa da resolução. O build inclui um teste básico de carga de classes; a consulta real continua sendo o teste necessário no classloader do WAS.

## HTTP 404 causado pelo teste

O validador escolhia uma porta local aleatória e a enviava no cabeçalho Host. O virtual host do WAS não reconhecia aquela porta. O teste passou a enviar `Host: localhost:9443`, mantendo o encaminhamento local aleatório. Antes de alterar a aplicação, verificar o context root e o virtual host.

## SQL State 28P01: password authentication failed

No caso investigado, a mesma senha montada no pod do WAS autenticou pelo psql, mas a aplicação continuava falhando. Isso isolou a diferença entre a credencial do Secret e a credencial gravada no alias J2C.

O AdminConfig mascarava o atributo de senha; por isso, tentar decodificar o valor retornado por essa API não confirmava igualdade. Uma comparação interna do security.xml demonstrou divergência, sem imprimir as credenciais. A edição manual do alias fez o teste de conexão e a aplicação funcionarem.

**Correção validada:** o runtime-auth.py passou a usar texto nativo do Jython e verificar a senha persistida contra o Secret antes de sinalizar sucesso. Após essa alteração e recriação do pod, foram observados LAB_AUTH_SECRET_MATCH=SIM e LAB_JDBC_OK. A alteração de representação foi parte da correção; não foi realizado um teste isolado que explique todos os detalhes internos da conversão anterior.

Não publicar security.xml, conteúdo de Secrets, senhas, dumps ou logs completos que possam conter dados sensíveis. Não usar nova troca de senha como primeira tentativa quando a credencial já foi validada.

## HTTP 503 na página JDBC

A página registra um identificador e a etapa: JNDI, CONNECTION ou QUERY. Correlacione com `WASLAB JDBC FAIL` no log. O validador mostra a resposta HTTP e restringe os logs ao início da requisição para não confundir erros antigos com o teste atual.

```bash
k3s kubectl logs -n websphere deployment/was --since=5m | grep 'WASLAB JDBC'
```

DSRA0174W indica uso de GenericDataStoreHelper. Examine a exceção e o resultado final; esse aviso, sozinho, não comprova falha da conexão.

## Falha na comparação da senha durante a inicialização

O script não inicia o WAS quando a verificação falha. Examine o log; não remova essa verificação para esconder a inconsistência. Confirme que a senha do banco e o Secret correspondem e que a versão correta do runtime-auth.py está no ConfigMap.

## Portas ocupadas

Use `ss -ltnp` no servidor para identificar um port-forward já existente. Mantenha um único encaminhamento nas portas fixas 9043/9443. A troca do pod pode encerrar o encaminhamento, que precisa ser aberto novamente.
