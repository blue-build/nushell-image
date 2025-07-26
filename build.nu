#!/usr/bin/env nu
# build separate images for each module in the repo

# version to be tagged with `default` and used by BlueBuild modules
const DEFAULT_VERSION = "0.106.0"

# architectures to build and the corresponding download arch string
const BUILD_ARCHS = [
    {
        docker: "linux/amd64",
        download: "x86_64",
    },
    {
        docker: "linux/arm64",
        download: "aarch64",
    }
]

print $"(ansi green_bold)Gathering images"

let images = http get https://api.github.com/repos/nushell/nushell/releases | enumerate | each { |arrayEl|
    let release = $arrayEl.item

    if not ($BUILD_ARCHS | all {|arch|
        ($release.assets | any {|asset|
            $asset.name | str contains $"($arch.download)-unknown-linux-musl"
        })
    }) {
        return
    }

    let version = $release.name

    let tags = (
        if ($env.GH_EVENT_NAME != "pull_request" and $env.GH_BRANCH == "main") {
            if ($arrayEl.index == 0 and $version == $DEFAULT_VERSION) {
                ["latest", "default", $version]
            } else if ($arrayEl.index == 0) {
                ["latest", $version]
            } else if ($version == $DEFAULT_VERSION) {
                ["default", $version]
            } else {
                [$version]
            }
        } else if ($env.GH_EVENT_NAME != "pull_request") {
            [$"($version)-($env.GH_BRANCH)"]
        } else {
            [$"($version)-pr-($env.GH_PR_NUMBER)"]
        }
    )
    print $"(ansi cyan)Found version & generated tags:(ansi reset) ($tags | str join ' ')"

    {
        version: $version
        tags: $tags
    }
}

print $"(ansi green_bold)Starting image build(ansi reset)"

$images | each { |img|
    let base_image = $"($env.REGISTRY)/nushell-image"

    $BUILD_ARCHS | each { |arch|
        print $"(ansi cyan)Building image for version:(ansi reset) ($img.version)"

        let tag = $"($base_image):($img.version)-($arch.download)"

        try {
            (docker build .
                -f ./Containerfile
                --platform $arch.docker
                -t $tag
                --build-arg $"VERSION=($img.version)"
                --build-arg $"DOWNLOAD_ARCH=($arch.download)")

            print $"(ansi cyan)Pushing image for platform ($arch.download) and version ($img.version):(ansi reset) ($tag)"
            docker push $tag
        } catch {
            print $"(ansi red_bold)Failed to build image(ansi reset) ($tag)"
            exit 1
        }
    }

    $img.tags | each { |tag|
        let final_image = $"($base_image):($tag)"

        try {
            print $"(ansi cyan)Creating multi-platform manifest:(ansi reset) ($final_image)"
            (docker manifest create $final_image
                ...($BUILD_ARCHS | each { |arch|
                    ["--amend", $"($base_image):($img.version)-($arch.download)"]
                } | flatten))

            print $"(ansi cyan)Pushing multi-platform manifest:(ansi reset) ($final_image)"
            docker manifest push $final_image

            (docker manifest inspect $final_image | from json).manifests | each { |manifest|
                let digest_image = $"($base_image)@($manifest.digest)"

                print $"(ansi cyan)Signing image:(ansi reset) ($digest_image)"
                cosign sign -y --key env://COSIGN_PRIVATE_KEY $digest_image
            }
        } catch {
            print $"(ansi red_bold)Failed to create and sign manifest(ansi reset) ($final_image)"
            exit 1
        }
    }
}

print $"(ansi green_bold)DONE!(ansi reset)"
