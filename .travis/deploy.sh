#! /bin/bash

#
# A simple script to publish our artifacts on a push to the "master" branch.
# Publishes snapshots or, if our version isn't a snapshot, stable artifacts.
#

# 'master' but setting to 'travis' for testing
if [[ "$TRAVIS_BRANCH" == "travis" && "$TRAVIS_PULL_REQUEST" == "false" ]]; then
  cd target

  # First we want to push our newly built artifacts to an S3 bucket
  for JAR in $(find webp-imageio-*.jar); do
    echo "Copying $JAR to S3 bucket"
    aws s3 cp --quiet "$JAR" s3://"$S3_BUCKET"/"$TRAVIS_BUILD_NUMBER"/"$JAR"
  done

  # Then get a list of bucket artifacts to see if all platforms have been built
  JARS=$(aws s3 ls s3://"$S3_BUCKET"/"$TRAVIS_BUILD_NUMBER"/)
  JAR_COUNT=$(echo "$JARS" | grep -c .)

  # Make sure we have all five build artifacts; if we do, go ahead and do a deploy
  if [[ "$JAR_COUNT" == "5" ]]; then
    cd ..

    echo "Copying published Jars from S3 into local 'target' directory"
    aws s3 cp --recursive --quiet s3://"$S3_BUCKET"/"$TRAVIS_BUILD_NUMBER"/ target/

    # What version of our artifacts have we built? This doesn't seem to work on Travis
    PROJECT_VERSION=$(mvn -q -Dexec.executable="echo" -Dexec.args='${project.version}' --non-recursive exec:exec)

    if [[ "$PROJECT_VERSION" == *"SNAPSHOT"* ]]; then
      echo "Deploying to the snapshot repository defined in the settings.xml file"
      mvn deploy -s target/classes/settings.xml -Pdeploy -Dmaven.main.skip -Dmaven.test.skip=true |grep Uploaded.*jar
    fi
  else
    echo "Not deploying yet because only $JAR_COUNT build artifacts are ready..."
  fi
fi
