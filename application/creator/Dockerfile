FROM ubuntu:jammy

RUN apt update -y
RUN apt install python3-pip curl -y

WORKDIR /tmp
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"


COPY ./main.py /opt/main.py
COPY ./requirments.txt /opt/requirments.txt
WORKDIR /opt
RUN pip3 install -r requirments.txt

CMD [ "python3", "main.py" ]