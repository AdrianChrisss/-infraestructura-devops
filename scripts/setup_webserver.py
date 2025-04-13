import os
import subprocess

# Detectar el hostname para personalizar la página
hostname = subprocess.getoutput("hostname")

# Instalar Apache
subprocess.run(["sudo", "apt-get", "update", "-y"])
subprocess.run(["sudo", "apt-get", "install", "apache2", "-y"])

# Crear contenido HTML personalizado
html_content = f"""
<html>
  <head><title>{hostname}</title></head>
  <body>
    <h1>Hola desde {hostname} 🚀</h1>
    <p>Servidor Web personalizado para infraestructura DevOps</p>
  </body>
</html>
"""

# Escribir el archivo en /var/www/html/index.html
with open("/tmp/index.html", "w") as file:
    file.write(html_content)

subprocess.run(["sudo", "mv", "/tmp/index.html", "/var/www/html/index.html"])

# Iniciar y habilitar Apache
subprocess.run(["sudo", "systemctl", "start", "apache2"])
subprocess.run(["sudo", "systemctl", "enable", "apache2"])

print("✅ Configuración del servidor web completada.")
    