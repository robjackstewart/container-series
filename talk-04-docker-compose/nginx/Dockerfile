FROM nginx:alpine
# This image only copies static Nginx configuration; no build-time network step needs extra CA certificates.
COPY nginx/nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
