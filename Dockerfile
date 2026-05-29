FROM stirlingtools/stirling-pdf:latest
ENV SECURITY_ENABLELOGIN=false
# Toggle between "classic" and "modern" to visibly verify a new deploy:
# the navbar logo style switches immediately and works without login.
ENV UI_LOGOSTYLE=classic

