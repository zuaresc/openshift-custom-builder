# This image is intended for testing purposes, it has the same behavior as
# the origin-docker-builder image, but does so as a custom image so it can
# be used with Custom build strategies.  It expects a set of
# environment variables to parameterize the build:
#
#   OUTPUT_REGISTRY - the Docker registry URL to push this image to
#   OUTPUT_IMAGE - the name to tag the image with
#   SOURCE_URI - a URI to fetch the build context from
#   SOURCE_REF - a reference to pass to Git for which commit to use (optional)
#
# This image expects to have the Docker socket bind-mounted into the container.
# If "/root/.docker/config.json" is bind mounted in, it will use that as authorization
# to a Docker registry.
#
# The standard name for this image is openshift/origin-custom-docker-builder
#
FROM openshift/origin-base
COPY docker.repo /etc/yum.repos.d/docker.repo
RUN yum clean all && yum makecache fast && yum update -y

RUN INSTALL_PKGS="gettext curl git docker-engine unzip" && \
    yum install -y $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum clean all

ENV JAVA_VERSION 1.8.0

RUN JAVA_PKGS="java-$JAVA_VERSION-openjdk java-$JAVA_VERSION-openjdk-devel" && \
  yum install -y $JAVA_PKGS && \
  rpm -V $JAVA_PKGS && \
  yum clean all

ENV JAVA_HOME /usr/lib/jvm/java

ENV MAVEN_VERSION 3.3.9
RUN curl -fsSL https://archive.apache.org/dist/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz | tar xzf - -C /usr/share \
  && mv /usr/share/apache-maven-$MAVEN_VERSION /usr/share/maven \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

ENV MAVEN_HOME /usr/share/maven

ENV GRADLE_VERSION 2.14
RUN curl -sL -0 https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip -o /tmp/gradle-${GRADLE_VERSION}-bin.zip && \
    unzip /tmp/gradle-${GRADLE_VERSION}-bin.zip -d /usr/local/ && \
    rm /tmp/gradle-${GRADLE_VERSION}-bin.zip && \
    mv /usr/local/gradle-${GRADLE_VERSION} /usr/local/gradle && \
    ln -sf /usr/local/gradle/bin/gradle /usr/local/bin/gradle

LABEL io.k8s.display-name="OpenShift Java Spring Boot Gradle Builder" \
      io.k8s.description="Docker Java Builder"

ENV HOME=/root
RUN mkdir -p /root/.ssh && touch /root/.ssh/id_rsa && chmod 600 /root/.ssh/id_rsa
RUN echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> /root/.ssh/config
COPY build.sh /tmp/build.sh

CMD ["/tmp/build.sh"]
