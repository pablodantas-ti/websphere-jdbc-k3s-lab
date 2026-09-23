# Operação do laboratório

## Atualizar configuração ou aplicação

1. Edite os JSPs em app/src/main/webapp ou image/configure-lab.py.
2. Para senha em runtime, edite image/runtime-auth.py, mantendo a verificação de igualdade.
3. Use uma nova tag nos scripts 01-build/02-deploy e nos manifests k8s/was-deployment.json e k8s/was-patch.json.
4. Execute a construção e o deploy:

```bash
bash scripts/01-build.sh
bash scripts/02-deploy.sh
bash scripts/03-validar.sh
```

O deploy reinicia o WAS quando a especificação da imagem muda. Se alterar somente o código do ConfigMap, execute também rollout restart; mounts subPath não atualizam o arquivo de um contêiner já em execução. Reutilizar uma tag pode manter a imagem antiga em cache.

## Alterar a senha do banco

A senha real no PostgreSQL, o Secret e o alias precisam ser consistentes. O Secret não executa ALTER ROLE no banco automaticamente.

Para mudar a senha do usuário:

```bash
k3s kubectl exec -it -n websphere deployment/postgres-lab -- psql -U labadmin -d labdb
```

Dentro do psql use `\password waslab`, informe a senha duas vezes e saia com `\q`. Atualize somente app-password no Secret postgres-lab-auth, preservando admin-password. Não coloque senhas literais em comandos gravados no histórico. Depois recrie o pod do WAS para reconfigurar o alias.

## Retomar um rollout com falha

```bash
k3s kubectl get pods -n websphere
k3s kubectl describe pod -n websphere -l app=was
k3s kubectl logs -n websphere deployment/was --tail=100
```

As mensagens de startup indicam se a configuração de credenciais concluiu. Um timeout no cliente kubectl não significa que o processo foi cancelado; inspecione antes de reaplicar.

Se existir uma revisão anterior funcional, `k3s kubectl rollout undo deployment/was -n websphere` restaura sua especificação. Isso não restaura alterações manuais antigas de dentro do contêiner, nem reverte o conteúdo de ConfigMaps mutáveis.

## Validação estática

Na raiz do repositório, com Python 3:

```bash
python3 tools/check_project.py
```

Em Linux, também valide a sintaxe Bash:

```bash
for f in executar.sh scripts/*.sh database/*.sh image/*.sh; do bash -n "$f" || exit; done
```

Esses testes não substituem o build com a JVM IBM e a consulta real no K3s. A validação estática verifica os vínculos e a consistência entre os artefatos publicados.
