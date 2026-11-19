from odoo import fields, models

class ResUsers(models.Model):
    _inherit = 'res.users'
    salesman_location_id = fields.Many2one('stock.location', string='Salesman Inventory',
        domain=[('usage', '=', 'internal')])

class CustomerRequest(models.Model):
    _name = 'salesman.customer.request'
    _description = 'Customer Request'
    _order = 'id desc'
    partner_id = fields.Many2one('res.partner', required=True)
    user_id = fields.Many2one('res.users', string='Salesman')
    product_id = fields.Many2one('product.product')
    qty = fields.Float(default=1)
    note = fields.Text()
    source = fields.Selection([('customer_app', 'Customer App'), ('salesman', 'Salesman')], default='customer_app')
    state = fields.Selection([('new', 'New'), ('seen', 'Seen'), ('done', 'Done'), ('cancel', 'Cancelled')], default='new')
