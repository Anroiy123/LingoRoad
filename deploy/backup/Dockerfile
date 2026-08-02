FROM postgres:16-alpine
COPY backup.sh /usr/local/bin/lingoroad-backup
RUN chmod 0555 /usr/local/bin/lingoroad-backup && \
    echo "15 2 * * * /usr/local/bin/lingoroad-backup" > /etc/crontabs/root
CMD ["crond", "-f", "-l", "2"]
