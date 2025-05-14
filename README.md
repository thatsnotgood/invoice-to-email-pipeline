# Invoice to E-Mail Pipeline

## Project Tree

```bash
invoice-to-email-pipeline/
├── data/
│   ├── raw/
│   └── processed/
├── R/
│   ├── import_data.R
│   ├── transform_data.R
│   └── compose_email.R        # Building email bodies & attachments
├── Rmd/
│   └── invoice.Rmd            # R Markdown template for invoice
├── scripts/                   # 'One-shot' command-line entry points
│   ├── 01_import.R
│   ├── 02_transform.R
│   ├── 03_render_invoice.R    # Renders PDF invoice via Rmd + LaTeX
│   └── 04_send_email.R        # Emails invoice PDF to client on schedule
├── output/                    # Generated PDFs and E-Mail logs
├── secrets/
├── tex/
│   └── invoice_template.tex   # LaTeX header/layout used by invoice.Rmd
├── assets/
│   └── company_logo.png
├── invoice-to-email-pipeline.Rproj
├── .Renviron
├── .gitignore
└── README.md
```
