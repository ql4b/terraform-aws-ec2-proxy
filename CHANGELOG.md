## <small>3.1.3 (2026-10-26)</small>

* docs: auto-update terraform-docs ([72a54b3](https://github.com/ql4b/terraform-aws-ec2-proxy/commit/72a54b3))
* build: bump hashicorp/aws from 6.58.0 to 6.70.0 (#19) ([20118e9](https://github.com/ql4b/terraform-aws-ec2-proxy/commit/20118e9)), closes [#19](https://github.com/ql4b/terraform-aws-ec2-proxy/issues/19)

## <small>3.1.2 (2026-10-26)</small>

* docs: auto-update terraform-docs ([ff41413](https://github.com/ql4b/terraform-aws-ec2-proxy/commit/ff41413))
* ci: bump actions/checkout from 4.4.0 to 7.0.1 (#16) ([5f8423f](https://github.com/ql4b/terraform-aws-ec2-proxy/commit/5f8423f)), closes [#16](https://github.com/ql4b/terraform-aws-ec2-proxy/issues/16)
* ci: bump actions/setup-node from 4.4.0 to 7.1.0 (#15) ([bdd163d](https://github.com/ql4b/terraform-aws-ec2-proxy/commit/bdd163d)), closes [#15](https://github.com/ql4b/terraform-aws-ec2-proxy/issues/15)
* ci: bump hashicorp/setup-terraform from 3.1.2 to 4.0.1 (#17) ([4a3f365](https://github.com/ql4b/terraform-aws-ec2-proxy/commit/4a3f365)), closes [#17](https://github.com/ql4b/terraform-aws-ec2-proxy/issues/17)
* ci: bump terraform-linters/setup-tflint from 4.1.1 to 6.3.2 (#18) ([1f8ca95](https://github.com/ql4b/terraform-aws-ec2-proxy/commit/1f8ca95)), closes [#18](https://github.com/ql4b/terraform-aws-ec2-proxy/issues/18)
* ci: harden CI per OpenSSF Scorecard (#13) ([fc8ccdd](https://github.com/ql4b/terraform-aws-ec2-proxy/commit/fc8ccdd)), closes [#13](https://github.com/ql4b/terraform-aws-ec2-proxy/issues/13)
* build: bump hashicorp/archive from 2.8.0 to 2.8.1 (#20) ([81404cc](https://github.com/ql4b/terraform-aws-ec2-proxy/commit/81404cc)), closes [#20](https://github.com/ql4b/terraform-aws-ec2-proxy/issues/20)
* build: bump hashicorp/http from 3.6.0 to 3.6.3 (#14) ([cd0917b](https://github.com/ql4b/terraform-aws-ec2-proxy/commit/cd0917b)), closes [#14](https://github.com/ql4b/terraform-aws-ec2-proxy/issues/14)

## <small>3.1.1 (2026-09-11)</small>

* docs: example READMEs + wrapper link; release docs as patch (#12) ([be7025f](https://github.com/ql4b/terraform-aws-ec2-proxy/commit/be7025f)), closes [#12](https://github.com/ql4b/terraform-aws-ec2-proxy/issues/12)
* docs: update CURRENT_STATE status to v3.1.0 (released) (#11) ([9873cfa](https://github.com/ql4b/terraform-aws-ec2-proxy/commit/9873cfa)), closes [#11](https://github.com/ql4b/terraform-aws-ec2-proxy/issues/11)

## 3.1.0 (2026-09-10)

* feat: tag instances with proxy:ttl-hours when a TTL is set (#10) ([13c1123](https://github.com/ql4b/terraform-aws-ec2-proxy/commit/13c1123)), closes [#10](https://github.com/ql4b/terraform-aws-ec2-proxy/issues/10)

## 3.0.0 (2026-09-10)

* docs: auto-update terraform-docs ([d804ba5](https://github.com/ql4b/terraform-aws-ec2-proxy/commit/d804ba5))
* feat!: manage the proxy via a single-instance ASG (v3) (#9) ([c9876ec](https://github.com/ql4b/terraform-aws-ec2-proxy/commit/c9876ec)), closes [#9](https://github.com/ql4b/terraform-aws-ec2-proxy/issues/9)

### BREAKING CHANGE

* removes the `spot` and `use_asg` variables and the
`public_ip`, `instance_id`, `proxy_url`, and `is_spot` outputs. The
running instance is now dynamic (ASG-managed); resolve its IP live via
the `proxy:managed-by` tag instead of a Terraform output. New output:
`launch_template_id`. Consumers needing the previous standalone-instance
behavior should pin `version = "~> 2.5"`.

## 2.5.0 (2026-08-31)

* fix(ci): pin conventional-changelog-conventionalcommits to v7 ([b9b51d9](https://github.com/ql4b/terraform-aws-ec2-proxy/commit/b9b51d9))
* docs: auto-update terraform-docs ([893b069](https://github.com/ql4b/terraform-aws-ec2-proxy/commit/893b069))
* feat: add optional vpc_id and subnet_id variables (#8) ([5c76fff](https://github.com/ql4b/terraform-aws-ec2-proxy/commit/5c76fff)), closes [#8](https://github.com/ql4b/terraform-aws-ec2-proxy/issues/8)

## [2.4.0](https://github.com/ql4b/terraform-aws-ec2-proxy/compare/v2.3.0...v2.4.0) (2026-08-11)

## [2.3.0](https://github.com/ql4b/terraform-aws-ec2-proxy/compare/v2.2.0...v2.3.0) (2026-08-11)

## [2.2.0](https://github.com/ql4b/terraform-aws-ec2-proxy/compare/v2.1.1...v2.2.0) (2026-08-10)
