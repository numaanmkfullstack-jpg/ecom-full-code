sudo docker build -t email-service .

sudo docker run -p 3005:3005 email-service



```
docker run -d \
  --name email-service \
  -p 3005:3005 \
  -e SEND_REAL_EMAIL=true \
  -e SMTP_USER=your-email@gmail.com \
  -e SMTP_PASSWORD=your-app-password \
  -e FROM_EMAIL=your-email@gmail.com \
  -e TO_EMAIL=admin@example.com \
  email-service
  