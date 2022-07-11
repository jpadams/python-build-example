FROM python:3.9
COPY . /app
CMD python -c "raise Exception('trying to break stuff')"
