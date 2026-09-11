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
