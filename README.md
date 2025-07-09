# **Provision Azure Infrastructure with Secure Terraform Deployment Using GitHub Actions**

This document summarizes the steps required to provision secure infrastructure in Azure using Terraform, configured with GitHub Actions for automation. It includes authentication through an Azure Service Principal and uses GitHub Secrets for secure credential management.

---

## **Requirements**

1. Provision the following Azure resources:
   - Virtual Network (VNet) with appropriate subnets.
   - Network Security Groups (NSGs) for traffic control.
   - Azure Load Balancer to distribute traffic.
   - Virtual Machine hosting a “Hello World” site.
2. Ensure infrastructure security follows Azure best practices.
3. Manage Terraform state files securely using Azure Blob Storage.
4. Use GitHub Actions for CI/CD automation of Terraform code.
5. Utilize ATMOS for modular design and development stack configuration.

---

## **Steps to Implement**

### **1. Create Azure Service Principal**
The Service Principal is used to authenticate Terraform scripts via GitHub Actions.

1. Open Azure CLI or Azure Cloud Shell.
2. Execute a command to create the Service Principal:
   - Assign `Contributor` role to the entire subscription for resource provisioning.
   - Alternatively, restrict permissions to a specific Resource Group.
3. Save the output values:
   - **Client ID** (`appId`)
   - **Client Secret** (`password`)
   - **Tenant ID** (`tenant`)
   - **Subscription ID**

---

### **2. Configure GitHub Secrets**
Store sensitive Azure credentials securely in GitHub Secrets to use them within the GitHub Actions workflow.

1. Open your GitHub repository.
2. Go to **Settings** > **Secrets and variables** > **Actions**.
3. Create the following repository secrets:
   - `AZURE_CLIENT_ID`: Client ID from the Service Principal.
   - `AZURE_CLIENT_SECRET`: Client Secret from the Service Principal.
   - `AZURE_TENANT_ID`: Tenant ID from the Service Principal.
   - `AZURE_SUBSCRIPTION_ID`: Azure Subscription ID.

---

### **3. Set Up Terraform Configuration**
Terraform scripts define desired Azure infrastructure, ensuring security and modularity:
1. Modules create resources such as VNet, NSGs, Load Balancer, Virtual Machines, etc.
2. Apply Azure best practices:
   - Restrict subnet access using NSGs.
   - Use Azure Blob Storage to securely manage Terraform state files.

---

### **4. Setup GitHub Actions for CI/CD**
Automate Terraform execution using GitHub Actions.

#### Steps:
1. Create or update a workflow file in the repository:
   - Authenticate Azure using **`azure/login@v1`** action with the Service Principal credentials stored in GitHub Secrets.
   - Execute Terraform commands like `terraform init`, `terraform plan`, and `terraform apply`.
2. Validate consistent deployment across environments.

---

### **5. Use ATMOS Framework for Modular Deployment**
ATMOS structures the Terraform configuration for better scalability and team collaboration:
1. Define modular components and stacks to segregate VNet, Load Balancer, VM, etc.
2. Configure stack-specific files for development environments.
3. Reference shared configurations for multiple environments (e.g., production, staging).

---

### **6. Validate Permissions**
Ensure the Service Principal has **Contributor** role permissions or custom permissions suitable for the resources defined in Terraform scripts.

---

### **7. Verify Security Best Practices**
1. Limit access to Terraform-managed Azure resources:
   - Restrict SSH ports only to designated IP ranges.
   - Disable unnecessary open ports in NSGs.
2. Use Azure Blob Storage to secure Terraform state files:
   - Avoid storing sensitive state files locally.

---

## **Outcomes**
By following these steps, you will achieve:
- Automated and secure provisioning of Azure resources.
- Modular Terraform deployment using ATMOS.
- Best practices implemented via Terraform and Azure NSGs.
- Centralized authentication in GitHub Actions with Azure Service Principal.

---

## **Useful Resources**
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Azure Service Principal](https://learn.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli)
- [ATMOS Framework](https://atmos.tools/docs/)

---

For questions or further clarifications, feel free to reach out!
