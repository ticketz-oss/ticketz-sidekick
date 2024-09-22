Ticketz Sidekick
================

Trata-se de um componente acessório, carregado em container e responsável por gerar arquivo de backup e também restaurar uma instalação a partir do arquivo gerado.

Ele pode ser usado em qualquer instalação do Ticketz, seja a versão Open Source ou a versão PRO, a instalação facilitada pode começar a fazer uso dele com comandos simples. Para instalações personalizadas é recomendado avaliar o funcionamento do pacote com base no código fonte dele github.com/ticketz-oss/ticketz-sidekick

Para instalar
-------------

Novas instalações a partir de hoje já vão vir com o componente instalado, então, caso você já tenha ele basta ir para a seção seguinte para ver como utilizá-lo.

A instalação facilitada apenas inclui o Sidekick na configuração do docker compose, para baixar essa atualização basta executar o update passando a versão que está utilizando.

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

### Executando um backup

Para executar um backup é preciso apenas posicionar-se dentro da pasta de instalação do sistema (geralmente `ticketz-docker-acme`) e executar o container. Os seguintes comandos fazem essa tarefa:

```bash
cd ~/ticketz-docker-acme
sudo docker compose run --rm sidekick backup
```

Após alguns minutos a pasta `backups` dentro deste arquivo terá um arquivo com a extensão `.tar.gz` que contém todos os arquivos das pastas `public` e `private` do backend e também um arquivo dump do banco de dados.

### Restaurando um backup

A restauração pode ser feita em várias maneiras, o método mais simples é utilizando o próprio comando de instalação facilitada tendo o arquivo de backup a ser restaurado na pasta corrente, o script de instalação irá executar o sidekick.

### Parâmetros

No arquivo .env-backend apenas um parâmetro é necessário para determinar quantos arquivos de backup deseja reter, a configuração padrão para esse parâmetro é 7 arquivos retidos.

### Agendamento

A execução periódica pode ser providenciada por qualquer mecanismo de agendamento, é apenas importante reforçar que é necessário que o script posicione-se dentro da pasta de instalação para ser executado. O exemplo abaixo presume que o caminho completo da pasta de instalação é `/home/ubuntu/ticketz-docker-acme`, e configura para ser executado diariamente (o sistema operacional executará esse script geralmente na madrugada).

```bash
cat > /etc/cron.daily/backup-ticketz.sh <<EOF
#/bin/bash

cd /home/ubuntu/ticketz-docker-acme
docker compose run --rm sidekick backup

EOF
```

Outras automações são possíveis após essa execução, como por exemplo enviar a cópia para outro sistema e apagar a cópia local.
