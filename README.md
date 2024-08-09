# packer-xtern
xtern packer repo

```sh
packer init .
packer fmt .
packer validate .
```

This block of code is from a Packer template and defines a shell provisioner. The provisioner is used to run shell commands during the image-building process. The `inline` argument specifies a list of commands to be executed in the order they are listed.

### Explanation:

```hcl
provisioner "shell" {
  inline = concat(
    var.use_ubuntu ? ["sudo apt update -y"] : [],
    var.use_redhat ? ["sudo yum update -y"] : [],
    [
      "sudo bash /tmp/security-scripts/001-critical-standards.sh",
      "sudo bash /tmp/security-scripts/002-critical-standards.sh"
    ]
  )
}
```

This line of code is part of a Packer configuration script, specifically within a `build` block. It uses a conditional (ternary) expression to determine which source(s) should be used when building an image. Here's the breakdown:

### Components of the Code:

1. **`build { ... }`**:
   - The `build` block in Packer defines how the image(s) should be built. It includes various configurations like sources, provisioners, and post-processors.

2. **`sources = ...`**:
   - This defines the sources from which the image(s) will be built. A source is typically an existing machine image that Packer will use as a base to build a new image.

3. **`var.use_ubuntu ? ["source.amazon-ebs.ubuntu"] : var.use_redhat ? ["source.amazon-ebs.redhat"] : []`**:
   - This is a conditional (ternary) expression that checks the value of two variables (`var.use_ubuntu` and `var.use_redhat`) to decide which source to use.

### How It Works:

1. **First Condition (`var.use_ubuntu ? ...`)**:
   - `var.use_ubuntu`: This is a variable (likely defined elsewhere in the Packer template or passed in as a variable) that indicates whether Ubuntu should be used as the source for the build.
   - If `var.use_ubuntu` is `true`, then the expression returns `["source.amazon-ebs.ubuntu"]`, meaning that the Ubuntu source will be used for the build.

2. **Second Condition (`: var.use_redhat ? ...`)**:
   - If `var.use_ubuntu` is `false`, the expression moves to the next condition, `var.use_redhat`.
   - `var.use_redhat`: This variable indicates whether Red Hat should be used as the source.
   - If `var.use_redhat` is `true`, then the expression returns `["source.amazon-ebs.redhat"]`, meaning that the Red Hat source will be used for the build.

3. **Fallback (`: []`)**:
   - If both `var.use_ubuntu` and `var.use_redhat` are `false`, the expression returns an empty list `[]`. This means no sources are specified, which could potentially result in an error or no image being built, depending on how the rest of the Packer configuration is set up.

### Summary:
- The code is selecting a source for building the image based on the values of `var.use_ubuntu` and `var.use_redhat`.
  - If `var.use_ubuntu` is `true`, the Ubuntu source is selected.
  - If `var.use_ubuntu` is `false` and `var.use_redhat` is `true`, the Red Hat source is selected.
  - If both are `false`, no sources are selected.

### Components:

1. **`provisioner "shell" { ... }`**:
   - This defines a shell provisioner in Packer, which allows you to run shell commands on the machine being built.

2. **`inline = concat(...)`**:
   - The `inline` argument is used to specify a list of shell commands that will be executed one after another. The `concat` function concatenates multiple lists into a single list.

3. **`var.use_ubuntu ? ["sudo apt update -y"] : []`**:
   - This is a conditional (ternary) expression. If the variable `var.use_ubuntu` is `true`, it adds the command `sudo apt update -y` to the list. This command updates the package lists on a Debian-based system (like Ubuntu) using `apt`.
   - If `var.use_ubuntu` is `false`, it returns an empty list `[]`, meaning nothing will be added to the command list.

4. **`var.use_redhat ? ["sudo yum update -y"] : []`**:
   - Similarly, this expression checks if `var.use_redhat` is `true`. If so, it adds the command `sudo yum update -y` to the list. This command updates the packages on a Red Hat-based system using `yum`.
   - If `var.use_redhat` is `false`, it returns an empty list `[]`.

5. **The final list**:
   ```hcl
   [
     "sudo bash /tmp/security-scripts/001-critical-standards.sh",
     "sudo bash /tmp/security-scripts/002-critical-standards.sh"
   ]
   ```
   - This is a fixed list of commands that will be executed regardless of whether Ubuntu or Red Hat is being used. The commands run two shell scripts (`001-critical-standards.sh` and `002-critical-standards.sh`) located in `/tmp/security-scripts/`. These scripts likely contain security hardening tasks.

### How It Works:

- **`concat` Function**:
  - The `concat` function merges the three lists into one.
  - Depending on the value of `var.use_ubuntu` and `var.use_redhat`, it conditionally adds the appropriate package update command to the list of commands.
  - The final list always includes the two security scripts.

### Example Scenarios:

1. **If `var.use_ubuntu` is `true` and `var.use_redhat` is `false`:**
   - The command list will be:
     ```bash
     sudo apt update -y
     sudo bash /tmp/security-scripts/001-critical-standards.sh
     sudo bash /tmp/security-scripts/002-critical-standards.sh
     ```

2. **If `var.use_redhat` is `true` and `var.use_ubuntu` is `false`:**
   - The command list will be:
     ```bash
     sudo yum update -y
     sudo bash /tmp/security-scripts/001-critical-standards.sh
     sudo bash /tmp/security-scripts/002-critical-standards.sh
     ```

3. **If both `var.use_ubuntu` and `var.use_redhat` are `false`:**
   - The command list will only include the security scripts:
     ```bash
     sudo bash /tmp/security-scripts/001-critical-standards.sh
     sudo bash /tmp/security-scripts/002-critical-standards.sh
     ```

### Summary:

This provisioner dynamically adjusts the commands it runs based on the operating system being used, ensuring that the appropriate package manager is updated (`apt` for Ubuntu and `yum` for Red Hat) and then running common security hardening scripts.