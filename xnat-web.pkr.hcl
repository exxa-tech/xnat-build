variable "xnat_version" {
  default = "1.8.2.2"
  type = string
}
variable "xnat_root" {
  default = "/data/xnat"
  type = string
}
variable "xnat_home" {
  default = "/data/xnat/home"
  type = string
}
variable "xnat_plugins" {
  default = "/data/xnat/home/plugins"
  type = string
}
variable "xnat_plugins_list" {
  default = [
    "container-service-3.0.0.jar",
    "ldap-auth-plugin-1.1.0.jar",
    "ohif-viewer-3.0.1.jar",
    "openid-auth-plugin-1.0.2.jar",
    "xsync-plugin-all-1.4.0.1.jar",
    "batch-launch-plugin-0.4.0.jar"
  ]
  type = list(string)
}
variable "run_as_uid" {
  default = "0"
  type = string
}
variable "docker_image" {
  default = "tomcat:9-jdk8-openjdk-buster"
  type = string
}

build {
  provisioner "shell" {
    inline = [
      "mkdir -p ${var.xnat_root}/{archive,build,cache,fileStore,ftp,inbox,pipeline,prearchive}",
      "mkdir -p ${var.xnat_home}/{config/auth,logs,plugins,themes,work}",
      "chown -R ${var.run_as_uid}:${var.run_as_uid} ${var.xnat_root} ${var.xnat_home}",
    ]
    inline_shebang = "/bin/bash -e"
  }

  provisioner "file" {
    destination = "${var.xnat_plugins}/"
    sources = var.xnat_plugins_list
  }

  provisioner "file" {
    destination = "/tmp/"
    sources = [
      "xnat-web-${var.xnat_version}.war",
      "packer_files"
    ]
    only = ["docker.xnat-web"]
  }

  provisioner "file" {
    destination = "${var.xnat_home}/config/"
    sources = [
      "xnat-conf.properties"
    ]
  }

  provisioner "file" {
    destination = "/"
    sources = [
      "docker-entrypoint.sh",
      "docker-entrypoint.d"
    ]
    only = [ "docker.xnat-web" ]
  }

  provisioner "shell" {
    inline = [
      "apt-get update",
      "apt-get -y install postgresql-client",
      "rm -rf $${CATALINA_HOME}/webapps/*",
      "unzip -o -d $${CATALINA_HOME}/webapps/ROOT /tmp/xnat-web-*.war",
      "sed -i 's/ch.qos.logback.core.rolling.RollingFileAppender/ch.qos.logback.core.ConsoleAppender/' $${CATALINA_HOME}/webapps/ROOT/WEB-INF/classes/logback.xml",
      "cp /tmp/packer_files/setenv.sh $${CATALINA_HOME}/bin/setenv.sh && chmod 0555 $${CATALINA_HOME}/bin/setenv.sh",
      "cp /tmp/packer_files/mq.png $${CATALINA_HOME}/webapps/ROOT/images/mq.png && chmod 0644 $${CATALINA_HOME}/webapps/ROOT/images/mq.png",
      "cp /tmp/packer_files/key.pem $${CATALINA_HOME}/certs/key.pem && chmod 0644 $${CATALINA_HOME}/certs/key.pem",
      "cp /tmp/packer_files/cert.pem $${CATALINA_HOME}/certs/cert.pem && chmod 0644 $${CATALINA_HOME}/certs/cert.pem",
      "cp /tmp/packer_files/ca.pem $${CATALINA_HOME}/certs/ca.pem && chmod 0644 $${CATALINA_HOME}/certs/ca.pem",
      "find ${var.xnat_home}/config ${var.xnat_plugins} -type d -exec chmod 0755 {} \\; && find ${var.xnat_plugins} -type f -exec chmod 0644 {} \\;",
      "rm -f $${CATALINA_HOME}/webapps/ROOT/WEB-INF/lib/dicom-xnat-mx-1.8.3.jar",
      "cp /tmp/packer_files/dicom-xnat-mx-1.8.2.jar $${CATALINA_HOME}/webapps/ROOT/WEB-INF/lib/dicom-xnat-mx-1.8.2.jar && chmod 0644 $${CATALINA_HOME}/webapps/ROOT/WEB-INF/lib/dicom-xnat-mx-1.8.2.jar",
      # Set local account as owner of XNAT config, plugins and Tomcat directories
      "chown -R ${var.run_as_uid}:${var.run_as_uid} ${var.xnat_home}/config ${var.xnat_plugins} $${CATALINA_HOME}",
      "[ -f /docker-entrypoint.sh ] && chmod 0755 /docker-entrypoint.sh",
      "[ -d /docker-entrypoint.d ] && find /docker-entrypoint.d -type d -exec chmod 0755 {} \\; && find /docker-entrypoint.d -type f -exec chmod 0644 {} \\; && chown -R ${var.run_as_uid}:${var.run_as_uid} /docker-entrypoint.d",
      "rm -rf /tmp/*",
      "rm -rf /var/lib/apt/lists/*"
    ]
  }

  post-processors {
    post-processor "docker-tag" {
      repository =  "archetype/${source.name}"
      tags = ["${var.xnat_version}"]
      only = ["docker.xnat-web"]
    }
    #post-processor "docker-push" { only = ["docker.xnat-web"]}
  }
  post-processors {
    post-processor "docker-tag" {
      repository =  "localhost:32000/${source.name}"
      tags = ["${var.xnat_version}"]
      only = ["docker.xnat-web"]
    }
  }

  sources = [
    "source.docker.xnat-web"
  ]
}

source "docker" "xnat-web" {
  changes = [
    "CMD [\"bin/catalina.sh\",\"run\"]",
    "ENTRYPOINT [\"/docker-entrypoint.sh\"]",
    "ENV XNAT_HOME=${var.xnat_home}",
    "LABEL maintainer=\"Alastair Ferguson <alastair.ferguson@exxa.tech\"",
    "LABEL org.opencontainers.image.source https://github.com/australian-imaging-service/xnat-build",
    "USER ${var.run_as_uid}",
    "VOLUME ${var.xnat_root}/archive ${var.xnat_root}/cache ${var.xnat_root}/prearchive ${var.xnat_home}/work"
  ]
  commit = true
  image = var.docker_image
}
