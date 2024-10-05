Ticketz Sidekick
================

Trata-se de um componente acessório para tarefas administrativas do Ticketz. As funções atuais do Ticketz Sidekick são as seguintes:

* `backup`: Backup do sistema (banco de dados e arquivos de mídia)
* `restore`: Restauração do sistema
* `retrieve`: Importação de outros sistemas derivados do Whaticket SaaS

Ele pode ser usado em qualquer instalação do Ticketz, seja a versão Open Source ou a versão PRO, ele é instalado automaticamente no uso da instalação rápida do Ticketz e pode ser usado com comandos simples.

Para instalações personalizadas é recomendado avaliar o funcionamento analisando o código fonte do repositório.

Para instalar
-------------

A partir do release desse projeto as instalações utilizando o método rápido automaticamente já passaram a instalar o sidekick.

Em instalações mais antigas pode ser necessário atualizar para incluir essa ferramenta.

Quem está utilizando a versão Open Source deve utilizar o comando:

```bash
curl -sSL update.ticke.tz | sudo bash -s main
```

Quem está utilizando a versão PRO deve utilizar o comando:

```bash
curl -sSL pro.ticke.tz | sudo bash -s pro
```

Para utilizar
-------------

A instalação apenas coloca o componente nas dependências, a execução dos backups, transferência do arquivo para outro armazenamento e a restauração precisam ser configuradas pelo administrador do sistema.

### Backup e Restore

#### Executando um backup

Para executar um backup é preciso apenas posicionar-se dentro da pasta de instalação do sistema (geralmente `ticketz-docker-acme`) e executar o container. Os seguintes comandos fazem essa tarefa:

```bash
cd ~/ticketz-docker-acme
sudo docker compose run --rm sidekick backup
```

Após alguns minutos a pasta `backups` dentro deste arquivo terá um arquivo com a extensão `.tar.gz` que contém todos os arquivos das pastas `public` e `private` do backend e também um arquivo dump do banco de dados.

#### Restaurando um backup

A restauração pode ser feita em várias maneiras, o método mais simples é utilizando o próprio comando de instalação facilitada tendo o arquivo de backup a ser restaurado na pasta corrente, o script de instalação irá executar o sidekick.

#### Parâmetros

No arquivo .env-backend apenas um parâmetro é necessário para determinar quantos arquivos de backup deseja reter, a configuração padrão para esse parâmetro é 7 arquivos retidos.

#### Agendamento

A execução periódica pode ser providenciada por qualquer mecanismo de agendamento, é apenas importante reforçar que é necessário que o script posicione-se dentro da pasta de instalação para ser executado. O exemplo abaixo presume que o caminho completo da pasta de instalação é `/home/ubuntu/ticketz-docker-acme`, e configura para ser executado diariamente (o sistema operacional executará esse script geralmente na madrugada).

```bash
cat > /etc/cron.daily/backup-ticketz.sh <<EOF
#/bin/bash

cd /home/ubuntu/ticketz-docker-acme
docker compose run --rm sidekick backup

EOF
```

Após gerar o arquivo de agendamento é necessário certificar-se de que ele é executável:

```bash
chmod +x /etc/cron.daily/backkup-ticketz.sh
```

Outras automações são possíveis após essa execução, como por exemplo enviar a cópia para outro sistema e apagar a cópia local.


### Importação de dados de outros sistemas

Para importar dados de outros sistemas não é necessário Docker, o melhor processo é instalar o script no mesmo servidor que possui os dados para minimizar o overheade de transferência de dados.

#### Download da ferramenta

Baixar o ticketz-sidekick no sistema de origem dos dados:

```bash
git clone https://github.com/ticketz-oss/ticketz-sidekick
```

Os comandos seguintes precisam ser executados dentro da pasta da ferramenta

```bash
cd ticketz-sidekick
```

#### Extração dos dados

O comando abaixo conecta-se no banco de dados e extrai as informações comuns à todos os derivados do Whaticket SaaS e vai salvar um arquivo com o nome `retrieved_data.tar.gz` na pasta `retrieve` (lembre de substituir os parâmetros do banco de dados):

```bash
./sidekick.sh retrieve dbHost dbName dbUser dbPass retrieve
```

#### Cópia da pasta public

O comando do sidekick apenas copia o banco de dados. Para a futura importação no Ticketz é interessante também copiar a pasta public do backend, pois ela contém os arquivos de mídias das conversas.

Para essa tarefa é necessário ir até a pasta onde os arquivos estão e gerar um arquivo `public_data.tar.gz` com todos os arquivos

```bash
cd /caminho/do/backend/public

tar -zcf ../public_data.tar.gz .
```

Após esse comando o arquivo `public_data.tar.gz` estará na pasta `/caminho/do/backend`

#### Importação dos dados em uma nova instalação do Ticketz

Para importar os dados extraídos é preciso apenas que os arquivos `retrieved_data.tar.gz` e `public_data.tar.gz` sejam copiados para a VPS ou servidor que irá rodar o Ticketz e começar o processo de instalação rápida.

> **IMPORTANTE:**
> 
> Fazer o checklist inicial de instalação
> 
> - [X] Servidor limpo com os comandos `git` e o `curl` funcionais
> - [X] DNS apontando para o hostname
> - [X] Portas 80 e 443 livres, sem proxy

Então, acessando a nova instalação e tendo copiado os arquivos para a pasta corrente basta rodar o comando de instalação:

```bash
curl -sSL get.ticke.tz | sudo bash -s hostname.example.com email@example.com
```

O processo pode demorar dependendo do volume de dados importado, após a conclusão o sistema estará disponível no hostname fornecido no comando. Os logins e senhas são os mesmos que já existiam no sistema de origem.
